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

(* The high-level interface creates one counter per event channel port.
   Every time the system receives a notification it increments the counter.
   Threads which have blocked elsewhere call 'after' which blocks until
   the stored counter is greater than the value they have already -- so
   if an event comes in between calls then it will not be lost.

   In the high-level interface it's almost impossible to miss an event.
   The only way you can miss is if you block while your port's counter
   wraps. Arguably if you have failed to notice 2bn (32-bit) wakeups then
   you have bigger problems. *)

let nr_events = 1024

type event = int

let program_start = min_int

type port = {
  mutable counter: event;
  c: unit Lwt_condition.t;
}

let ports = Array.init nr_events (fun _ -> { counter = program_start; c = Lwt_condition.create () })

let dump () =
  Printf.printf "Number of received event channel events:\n";
  for i = 0 to nr_events - 1 do
    if ports.(i).counter <> program_start
    then Printf.printf "port %d: %d\n%!" i (ports.(i).counter - program_start)
  done

let after evtchn counter =
  ignore(Eventchn.init ()); (* raise an exception if we have no event channels *)
  let port = Eventchn.to_int evtchn in
  lwt () = while_lwt ports.(port).counter <= counter && (Eventchn.is_valid evtchn) do
      Lwt_condition.wait ports.(port).c
    done in
  if Eventchn.is_valid evtchn
  then Lwt.return ports.(port).counter
  else Lwt.fail Generation.Invalid

external fd: Eventchn.handle -> Unix.file_descr = "stub_evtchn_fd"
external pending: Eventchn.handle -> Eventchn.t = "stub_evtchn_pending"

let event_cb = Array.init nr_events (fun _ -> Lwt_sequence.create ())

let wait port =
  ignore(Eventchn.init ()); (* raise an exception if we have no event channels *)
  let th, u = Lwt.task () in
  let node = Lwt_sequence.add_r u event_cb.(Eventchn.to_int port) in
  Lwt.on_cancel th (fun _ -> Lwt_sequence.remove node);
  th

let wake port =
  let port = Eventchn.to_int port in
  Lwt_sequence.iter_node_l (fun node ->
      let u = Lwt_sequence.get node in
      Lwt_sequence.remove node;
      Lwt.wakeup_later u ();
    ) event_cb.(port);
  ports.(port).counter <- ports.(port).counter + 1;
  Lwt_condition.broadcast ports.(port).c ()

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

let activations_thread =
  try
    run_real (Eventchn.init ())
  with _ ->
    (* Don't fail on application startup, fail explicit calls instead *)
    Lwt.return ()

(* Here for backwards compatibility *)
let run _ = ()

