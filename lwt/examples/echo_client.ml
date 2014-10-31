
open Ex_common
open Lwt

let echo_client ?ca host port =
  let open Lwt_io in
  lwt () = Tls_lwt.rng_init () in

  let port          = int_of_string port in
  lwt authenticator = X509_lwt.authenticator
    (match ca with
     | None        -> `Ca_dir ca_cert_dir
     | Some "NONE" -> `No_authentication_I'M_STUPID
     | Some f      -> `Ca_file f)
  in
  lwt certificate =
    X509_lwt.private_of_pems
      ~cert:server_cert
      ~priv_key:server_key
  in
  lwt (ic, oc) =
    Tls_lwt.connect_ext
      ~trace:eprint_sexp
      Tls.Config.(client ~authenticator ~certificates:(`Single certificate) ~ciphers:Ciphers.supported ())
      (host, port)
  in
  Lwt.join [
    lines ic    |> Lwt_stream.iter_s (printf "+ %s\n%!") ;
    lines stdin |> Lwt_stream.iter_s (write_line oc)
  ]

let () =
  try (
    match Sys.argv with
    | [| _ ; host ; port ; trust |] -> Lwt_main.run (echo_client host port ~ca:trust)
    | [| _ ; host ; port |]         -> Lwt_main.run (echo_client host port)
    | [| _ ; host |]                -> Lwt_main.run (echo_client host "443")
    | args                          -> Printf.eprintf "%s <host> <port>\n%!" args.(0) ) with
  | Tls_lwt.Tls_alert al ->
     Printf.eprintf "TLS ALERT: %s\n%!" (Tls.Packet.alert_type_to_string al) ;
     raise (Tls_lwt.Tls_alert al)

