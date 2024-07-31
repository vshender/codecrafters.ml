open Lwt
open Lwt.Syntax

module HTTPResponse = struct
  open Faraday

  (** Type of HTTP responses. *)
  type t = {
    version : int * int;
    status  : int;
    body    : string;
  }

  let status_codes = [
    (200, "200 OK");
  ]

  (** [make ?version ?status ?body ()] creates an HTTP response. *)
  let make ?(version=(1, 1)) ?(status=200) ?(body="") () =
    { version; status; body }

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

(** [handle_request sock] handles an incoming HTTP request. *)
let handle_request sock =
  let open Faraday_lwt_unix in

  (* Create a response. *)
  let resp = HTTPResponse.make () in
  let sr = Faraday.create 0x1000 in
  HTTPResponse.serialize sr resp;
  Faraday.close sr;

  (* Serialize the response. *)
  serialize
    ~yield:(fun _ -> pause ())
    ~writev:(writev_of_fd sock)
    sr

(** [server] runs an HTTP server. *)
let server =
  let open Lwt_unix in

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
    finalize
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
      (fun () ->
         close csock)
    >>= serve
  in

  serve ()

let () =
  Lwt_main.run server
