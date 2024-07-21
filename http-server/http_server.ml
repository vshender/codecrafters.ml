open Unix

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

(** [send_response sock sr] sends the serialized HTTP response [sr] to
    [sock]. *)
let send_response sock t =
  let open Faraday in
  let shutdown () =
    close t;
    ignore (Faraday.drain t)
  in
  let rec loop () =
    match Faraday.operation t with
    | `Writev iovecs ->
      let { buffer; off; len } = List.hd iovecs in
      let n = write_bigarray sock buffer off len in
      if n >= 0 then shift t n else shutdown ();
      loop ()
    | `Close -> ()
    | `Yield -> assert false
  in loop ()

(** [handle_request sock] handles an incoming HTTP request. *)
let handle_request sock =
  let resp = HTTPResponse.make () in
  let sr = Faraday.create 0x1000 in
  HTTPResponse.serialize sr resp;
  Faraday.close sr;
  send_response sock sr

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
    let csock, caddr = accept ~cloexec:true ssock in
    let cni = getnameinfo caddr [] in
    Printf.printf "Connection from %s:%s\n%!" cni.ni_hostname cni.ni_service;

    begin
      try
        (* Handle a request. *)
        handle_request csock;
        (* Close the connection to the client. *)
        shutdown csock SHUTDOWN_ALL
      with
        e -> Printf.printf "Error: %s\n%!" @@ Printexc.to_string e
    end;
    close csock
  done

let () = server ()
