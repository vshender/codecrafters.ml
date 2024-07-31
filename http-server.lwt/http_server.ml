open Lwt.Syntax

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
    let* _ = accept ~cloexec:true ssock in
    serve ()
  in

  serve ()

let () =
  Lwt_main.run server
