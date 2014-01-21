(* Copyright (C) Citrix Inc
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

external fd: Eventchn.handle -> Unix.file_descr = "stub_evtchn_fd"
external pending: Eventchn.handle -> Eventchn.t = "stub_evtchn_pending"

let nr_events = 1024
let event_cb = Array.init nr_events (fun _ -> Lwt_sequence.create ())

let wait port =
  let th, u = Lwt.task () in
  let node = Lwt_sequence.add_r u event_cb.(Eventchn.to_int port) in
  Lwt.on_cancel th (fun _ -> Lwt_sequence.remove node);
  th

let wake port =
  let port = Eventchn.to_int port in
  Lwt_sequence.iter_node_l (fun node ->
      let u = Lwt_sequence.get node in
      Lwt_sequence.remove node;
      Lwt.wakeup_later u ()
    ) event_cb.(port)

(* Go through the event mask and activate any events, potentially spawning
   new threads *)
let run_real xe =
  let fd = Lwt_unix.of_unix_file_descr ~blocking:false ~set_flags:true (fd xe) in
  let rec inner () =
    lwt () = Lwt_unix.wait_read fd in
    let port = pending xe in
    wake port;
    Eventchn.unmask xe port;
    inner ()
  in inner ()

let activations_thread = run_real (Eventchn.init ())

(* Here for backwards compatibility *)
let run _ = ()

(* High-level interface: it's not possible for us to lose an event since
   they are queued in the kernel driver. *)
type event = unit

let program_start = ()

let after port _ = wait port
