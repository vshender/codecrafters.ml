open Unix

(** [server ()] runs an HTTP server. *)
let server () =
  (* Create a TCP socket bound to the given address. *)
  let saddr = ADDR_INET (inet_addr_of_string "127.0.0.1", 4221) in
  let ssock = socket PF_INET SOCK_STREAM 0 in
  setsockopt ssock SO_REUSEADDR true;
  bind ssock saddr;
  listen ssock 10;

  while true do
    (* Wait for a connection *)
    let _, _ = accept ~cloexec:true ssock in
    ()
  done

let () = server ()
