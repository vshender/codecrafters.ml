open Cmdliner
open Lwt
open Lwt.Syntax

module HTTPRequest = struct
  (** Type of HTTP methods. *)
  type meth =
    | GET
    | POST
  [@@deriving show { with_path = false }]

  (** Type of HTTP requests. *)
  type t = {
    meth    : meth;
    path    : string;
    version : int * int;
    headers : (string * string) list;
    body    : string;
  }
  [@@deriving show { with_path = false }]

  module Parse = struct
    open Angstrom

    (** [is_space c] is true if [c] is a whitespace character. *)
    let is_space = function
      | ' ' | '\t' -> true
      | _          -> false

    (** [is_digit c] is true if [c] is a digit. *)
    let is_digit = function
      | '0' .. '9' -> true
      | _          -> false

    (** [digits] parses one or more digit characters. *)
    let digits = take_while1 is_digit

    (** [spaces] parses whitespace characters and discards them. *)
    let spaces = skip_while is_space

    (** [lex p] parses [p] followed by whitespace characters. *)
    let lex p = p <* spaces

    (** [meth] parses an HTTP method. *)
    let meth =
      take_till is_space >>= function
      | "GET"  -> return GET
      | "POST" -> return POST
      | _      -> fail "unknown method"

    (** [uri] parses a URI. *)
    let uri = take_till is_space

    (** [version] parses an HTTP version. *)
    let version =
      string "HTTP/" *>
      lift2 (fun major minor -> int_of_string major, int_of_string minor)
        (digits <* char '.')
        digits

    (** [request_first_line] parses the first line of an HTTP request. *)
    let request_first_line =
      lift3 (fun meth path version -> (meth, path, version))
        (lex meth)
        (lex uri)
        version

    (** [header] parses an HTTP header. *)
    let header =
      lift2 (fun name value -> String.(lowercase_ascii name, trim value))
        (take_till (Char.equal ':') <* char ':')
        (take_till (Char.equal '\r'))

    (** [headers] parses HTTP headers. *)
    let headers =
      fix
        (fun m ->
           (string "\r\n" >>| fun _ -> [])
           <|>
           lift2 (fun h t -> h :: t)
             (header <* string "\r\n")
             m)

    (** [request] parses an HTTP request. *)
    let request =
      request_first_line <* string "\r\n" >>= fun (meth, path, version) ->
      headers >>= fun headers ->
      List.assoc_opt "content-length" headers
      |> Option.map int_of_string
      |> Option.value ~default:0
      |> take >>| fun body ->
      { meth; path; version; headers; body }
  end
end

module HTTPResponse = struct
  open Faraday

  (** Type of HTTP responses. *)
  type t = {
    version : int * int;
    status  : int;
    headers : (string * string) list;
    body    : string;
  }
  [@@deriving show { with_path = false }]

  (** [make ?version ?status ?headers ?body ()] creates an HTTP response. *)
  let make ?(version=(1, 1)) ?(status=200) ?(headers=[]) ?(body="") () =
    let headers =
      let body_len = String.length body in
      if body_len > 0 then
        headers
        |> List.remove_assoc "Content-Length"
        |> List.cons ("Content-Length", string_of_int (String.length body))
      else
        headers
    in { version; status; headers; body }

  let status_codes = [
    (200, "200 OK");
    (201, "201 Created");
    (404, "404 Not Found");
    (500, "500 Internal Server Error");
  ]

  (** [serialize sr r] serializes the given HTTP response [r]. *)
  let serialize sr r =
    let major, minor = r.version in
    let status_code, headers, body =
      match List.assoc_opt r.status status_codes with
      | Some status_code -> status_code, r.headers, r.body
      | None             -> List.assoc 500 status_codes, [], ""
    in
    write_string sr (Printf.sprintf "HTTP/%d.%d " major minor);
    write_string sr status_code;
    write_string sr "\r\n";
    List.iter
      (fun (h, v) ->
         write_string sr h;
         write_string sr ": ";
         write_string sr v;
         write_string sr "\r\n")
      headers;
    write_string sr "\r\n";
    write_string sr body
end

(** [read_request sock] reads an HTTP-request from a client socket. *)
let read_request sock =
  let* _, r = Angstrom_lwt_unix.parse
      HTTPRequest.Parse.request
      (Lwt_io.of_fd ~mode:Lwt_io.Input sock)
  in
  return r

(** [write_response sock resp] writes the given HTTP-response to a client
    socket. *)
let write_response sock resp =
  (** Serialize the response. *)
  let sr = Faraday.create 0x1000 in
  HTTPResponse.serialize sr resp;
  Faraday.close sr;

  (* Send the response. *)
  Faraday_lwt_unix.serialize
    ~yield:(fun _ -> pause ())
    ~writev:(Faraday_lwt_unix.writev_of_fd sock)
    sr

(** [handle_request sock base_dir] handles an incoming HTTP request. *)
let handle_request sock base_dir =
  let* resp =
    let* req = read_request sock in
    match req with
    | Ok req ->
      let* () = Lwt_fmt.printf "Request: %s\n%!" @@ HTTPRequest.show req in

      if req.meth = HTTPRequest.POST then begin
        (* File created response. *)
        if String.starts_with ~prefix:"/files/" req.path then
          let filename = String.sub req.path 7 (String.length req.path - 7) in
          let filepath = Filename.concat base_dir filename in
          Lwt_io.(with_file ~mode:Output filepath) @@ fun oc ->
          let* () = Lwt_io.write oc req.body in
          return @@ HTTPResponse.make ~status:201 ()

        else
          (* A 404 Not Found response. *)
          return @@ HTTPResponse.make ~status:404 ()
      end else begin
        if req.path = "/" then
          (* A 200 OK response. *)
          return @@ HTTPResponse.make ()

        else if String.starts_with ~prefix:"/echo/" req.path then
          (* Echo response. *)
          return @@ HTTPResponse.make
            ~headers:[("Content-Type", "text/plain")]
            ~body:(String.sub req.path 6 (String.length req.path - 6))
            ()

        else if req.path = "/user-agent" then
          (* User-Agent response. *)
          return @@ HTTPResponse.make
            ~headers:[("Content-Type", "text/plain")]
            ~body:(Option.value (List.assoc_opt "user-agent" req.headers) ~default:"unknown")
            ()

        else if String.starts_with ~prefix:"/files/" req.path then
          (* File response. *)
          let filename = String.sub req.path 7 (String.length req.path - 7) in
          let filepath = Filename.concat base_dir filename in
          try_bind
            (fun () -> Lwt_unix.(access filepath [F_OK]))
            (fun () ->
               Lwt_io.(with_file ~mode:Input filepath) @@ fun ic ->
               let* body = Lwt_io.read ic in
               return @@ HTTPResponse.make
                 ~status:200
                 ~headers:[("Content-Type", "application/octet-stream")]
                 ~body:body
                 ())
            (fun _ ->
               return @@ HTTPResponse.make ~status:404 ())
        else
          (* A 404 Not Found response. *)
          return @@ HTTPResponse.make ~status:404 ()
      end
    | Error _ ->
      let* () = Lwt_fmt.printf "Request: reading error\n%!" in

      return @@ HTTPResponse.make ~status:500 ()
  in
  let* () = Lwt_fmt.printf "Response: %s\n%!" @@ HTTPResponse.show resp in

  (* Send the response. *)
  write_response sock resp

(** [server base_dir] runs an HTTP server. *)
let server base_dir =
  let open Lwt_unix in

  let* () = Lwt_fmt.printf "Publish directory: %s\n%!" base_dir in

  (* Ignore the SIGPIPE signal to prevent the program from terminating when
     attempting to write to a closed socket. *)
  ignore Sys.(signal sigpipe Signal_ignore);

  (* Create a TCP socket bound to the given address. *)
  let saddr = ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", 4221) in
  let ssock = socket PF_INET SOCK_STREAM 0 in
  setsockopt ssock SO_REUSEADDR true;
  ignore (bind ssock saddr);
  listen ssock 10;

  (* Serve incoming request. *)
  let rec serve () =
    (* Wait for a connection. *)
    let* (csock, caddr) = accept ~cloexec:true ssock in
    ignore @@ begin
      catch
        (fun () ->
           let* cni = getnameinfo caddr [] in
           let* () = Lwt_fmt.printf
               "Connection from %s:%s\n%!" cni.ni_hostname cni.ni_service
           in

           (* Handle a request. *)
           let* () = handle_request csock base_dir in
           (* Close the connection to the client. *)
           shutdown csock SHUTDOWN_ALL;

           return_unit)
        (fun exc ->
           Lwt_fmt.printf
             "Request handling error: %s\n%!" @@ Printexc.to_string exc)
      >>= fun () ->
      close csock
    end;
    serve ()
  in

  serve ()

(** [base_dir] is a command-line argument representing a directory to publish. *)
let base_dir =
  let doc = "A directory to publish" in
  Arg.(value & opt string "/tmp" & info ["d"; "directory"] ~docv:"DIR" ~doc)

(** [cmd] is a command-line interface for the HTTP server.  *)
let cmd =
  let doc = "training HTTP-server" in
  let info = Cmd.info "http_server" ~doc in
  Cmd.v info
    Term.(const (fun base_dir -> Lwt_main.run @@ server base_dir) $
          base_dir)

let () =
  exit (Cmd.eval cmd)
