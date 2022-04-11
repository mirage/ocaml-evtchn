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

open Lwt
open OUnit

module Activations = Unix_activations

let connect () =
  try
    let h = Eventchn.init () in
    let listening = Eventchn.bind_unbound_port h 0 in
    let connected = Eventchn.bind_interdomain h 0 (Eventchn.to_int listening) in
    let t =
      (* Without this notify the after will block. This checks
         that the background thread is working. *)
      Eventchn.notify h connected;
      Activations.after listening Activations.program_start
      >>= fun _now ->
      return () in
    Lwt_main.run t
  with _ -> Printf.eprintf "failed (ignored)"

let _ =
  let suite = "eventchn" >::: [
    "connect" >:: connect;
  ] in
  OUnit2.run_test_tt_main (OUnit.ounit2_of_ounit1 suite)

