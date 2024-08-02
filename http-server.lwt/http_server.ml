open Lwt
open Lwt.Syntax

module HTTPRequest = struct
  (** Type of HTTP methods. *)
  type meth =
    | GET
  [@@deriving show { with_path = false }]

  (** Type of HTTP requests. *)
  type t = {
    meth    : meth;
    path    : string;
    version : int * int;
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
      | "GET" -> return GET
      | _     -> fail "unknown method"

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

    (** [request] parses an HTTP request. *)
    let request =
      request_first_line >>| fun (meth, path, version) ->
      { meth; path; version }
  end
end

module HTTPResponse = struct
  open Faraday

  (** Type of HTTP responses. *)
  type t = {
    version : (int * int [@default (1, 1)]);
    status  : (int       [@default 200]);
    body    : (string    [@default ""]);
  }
  [@@deriving make, show { with_path = false }]

  let status_codes = [
    (200, "200 OK");
    (404, "404 Not Found");
    (500, "500 Internal Server Error");
  ]

  (** [serialize sr r] serializes the given HTTP response [r]. *)
  let serialize sr r =
    let major, minor = r.version
    and status_code =
      try
        List.assoc r.status status_codes
      with
      | Not_found ->
        List.assoc 500 status_codes
    in
    write_string sr (Printf.sprintf "HTTP/%d.%d " major minor);
    write_string sr status_code;
    write_string sr "\r\n";
    write_string sr "\r\n";
    write_string sr r.body
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

(** [handle_request sock] handles an incoming HTTP request. *)
let handle_request sock =
  let* resp =
    let* req = read_request sock in
    match req with
    | Ok req ->
      let* () = Lwt_fmt.printf "Request: %s\n%!" @@ HTTPRequest.show req in

      if req.path = "/" then
        (* A 200 OK response. *)
        return (HTTPResponse.make ())
      else
        (* A 404 Not Found response. *)
        return (HTTPResponse.make ~status:404 ())
    | Error _ ->
      let* () = Lwt_fmt.printf "Request: reading error\n%!" in

      return (HTTPResponse.make ~status:500 ())
  in
  let* () = Lwt_fmt.printf "Response: %s\n%!" @@ HTTPResponse.show resp in

  (* Send the response. *)
  write_response sock resp

(** [server] runs an HTTP server. *)
let server =
  let open Lwt_unix in

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
    let* () = catch
        (fun () ->
           let* cni = getnameinfo caddr [] in
           let* () = Lwt_fmt.printf
               "Connection from %s:%s\n%!" cni.ni_hostname cni.ni_service
           in

           (* Handle a request. *)
           let* () = handle_request csock in
           (* Close the connection to the client. *)
           shutdown csock SHUTDOWN_ALL;

           return_unit)
        (fun exc ->
           Lwt_fmt.printf
             "Request handling error: %s\n%!" @@ Printexc.to_string exc)
    in
    close csock
    >>= serve
  in

  serve ()

let () =
  Lwt_main.run server
