
open Ex_common
open Lwt

let echo_client ?ca host port =
  let port = int_of_string port in
  lwt validator = X509_lwt.validator
    (match ca with
     | None        -> `Ca_dir ca_cert_dir
     | Some "NONE" -> `No_validation_I'M_STUPID
     | Some f      -> `Ca_file f)
  in
  lwt (ic, oc) = Tls_lwt.connect validator (host, port) in
  let rec network () =
    Lwt_io.(read_line ic >>= printf "+ %s\n%!" >> network ())
  and keyboard () =
    Lwt_io.(read_line stdin >>= write_line oc >> keyboard ())
  in
  Lwt.join [ network () ; keyboard () ]

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

