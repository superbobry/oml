(*
   Copyright 2015:
     Leonid Rozenberg <leonidr@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)

open Test_utils
open Util

let () =
  let add_simple_test = Test.add_simple_test_group "Util" in
  let add_random_test
    ?title ?nb_runs ?nb_tries ?classifier
    ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec =
    Test.add_random_test_group "Util"
      ?title ?nb_runs ?nb_tries ?classifier
      ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec
  in
  add_simple_test ~title:"midpoint"
    (fun () -> Assert.equal_float 1.0 (midpoint 0.0 2.0));
  add_simple_test ~title:"significantly different"
    (fun () -> Assert.is_true (significantly_different_from 1.0 2.0));
  add_simple_test ~title:"significantly different modulo d"
    (fun () -> Assert.is_false (significantly_different_from ~d:0.1 1.0 1.1));
  add_simple_test ~title:"Can tell nan's"
    (fun () -> Assert.is_true (is_nan nan));
  add_simple_test ~title:"Can tell nan's in weird places."
    (fun () -> Assert.is_true (is_nan [| nan |].(0)));
  add_simple_test ~title:"Can determine degenerates"
    (fun () -> Assert.is_true (is_degenerate nan &&
                               is_degenerate neg_infinity &&
                               is_degenerate infinity));

  add_random_test ~title:"Normal float generates non degenerate values."
    ~nb_runs:10000 Gen.(bfloat max_float) (fun x -> is_degenerate x)
      Spec.([ just_postcond_pred is_false]);

  add_simple_test ~title:"Within works1."
    (fun () ->
      let bp = Open 3.0, Open 5.0 in
      Assert.is_true (within bp 4.0);
      Assert.is_false (within bp 5.0));

  add_simple_test ~title:"Within works2."
    (fun () ->
      let bp = Closed (-5.0), Open 5.0 in
      Assert.is_true (within bp (-5.0));
      Assert.is_false (within bp 6.0));

  add_simple_test ~title:"Within works3."
    (fun () ->
      let bp = Closed 3.0, Closed 5.0 in
      Assert.is_true (within bp 5.0);
      Assert.is_false (within bp 2.0));

  add_simple_test ~title:"Within works4."
    (fun () ->
      let bp = Open 3.0, Closed 5.0 in
      Assert.is_true (within bp 4.0);
      Assert.is_false (within bp 3.0));

  (* Array stuff *)
  let add_simple_test = Test.add_simple_test_group "Array" in
  let add_random_test
    ?title ?nb_runs ?nb_tries ?classifier
    ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec =
    Test.add_random_test_group "Array"
      ?title ?nb_runs ?nb_tries ?classifier
      ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec
  in
  let add_partial_random_test
    ?title ?nb_runs ?nb_tries ?classifier
    ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec =
    Test.add_partial_random_test_group "Array"
      ?title ?nb_runs ?nb_tries ?classifier
      ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec
  in
  let open Array in
  let id b = b in
  add_simple_test ~title:"Any works."
    (fun () -> Assert.is_true (any id [| true; true |]
                            && any id [| false; true |]
                            && any id [| true; false |]
                       && not (any id [| false; false |])));
  add_simple_test ~title:"All works."
    (fun () -> Assert.is_true (all id [| true; true |]
                       && not (all id [| true; false |])
                       && not (all id [| false; true |])
                       && not (all id [| false; false |])));

  add_simple_test
    ~title:"Has_order"
    (fun () ->
        Assert.is_true (has_order ( > ) [| 3;2;1|]
                     && has_order ( < ) [| 0;2;4|]
                && not (has_order ( > ) [| 10.0; 0.0; 10.0; |])
                && not (has_order ( < ) [| 10.0; 0.0; 10.0; |])));

  add_simple_test ~title:"Range simple."
    (fun () ->
      Assert.is_true (range ~start:3.0 ~stop:4.0 () = [| 3.0 |]));

  add_random_test
    ~title:"Range default increment is 1 and yields arrays of length 1."
    Gen.(bfloat 1e15)       (* 'fun' calculation. *)
    (fun start -> range ~start ~stop:(start +. 1.0) () = [| start |])
    Spec.([ just_postcond_pred is_true]);

  add_random_test
    ~title:"Precise binary search recovers elements"
    Gen.(fixed_length_array 100 int)
    (fun arr ->
      let find_me = arr.(0) in
      sort compare arr;
      let bsidx = binary_search (compare find_me) arr in
      let bsidx2 = binary_search_exn (compare find_me) arr in
      bsidx >= 0 && bsidx < 100 && bsidx2 >= 0 && bsidx2 < 100)
    Spec.([just_postcond_pred is_true]);

  add_random_test
    ~title:"Binary search (and exn) fails as specified"
    ~nb_runs:10000
    Gen.(zip3
          (make_int 0 100)
          (make_float (-1.0) 1.0)
          (fixed_length_array 100 (bfloat 1e3)))
    (fun (idx, delta, arr) ->
      sort compare arr;
      let find_me   = arr.(idx) +. delta in
      let bsidx     = binary_search (compare find_me) arr in
      let notfound  =
        try let _ = binary_search_exn (compare find_me) arr in false
        with Not_found  -> true
      in
      bsidx >= -1 && bsidx < 100 && notfound)
    Spec.([just_postcond_pred is_true]);

  let equal_arrays = (fun (x, y) -> Array.length x = Array.length y) in
  add_partial_random_test
    ~title:"zip and unzip"
    Gen.(zip2 (array (make_int 1 3) int) (array (make_int 1 3) char))
    (fun (z1, z2) -> (z1, z2) = unzip (zip z1 z2))
    Spec.([ equal_arrays       ==> is_result is_true
          ; (not equal_arrays) ==> is_exception is_invalid_arg
          ]);

  add_random_test
    ~title:"permutes preserve elements"
    Gen.(fixed_length_array 10 int)
    (fun arr ->
       let p = permute arr in
       sort compare p;
       sort compare arr;
       arr = p)
    Spec.([just_postcond_pred is_true]);

  (* The idea behind this test is that with Kahan's compensation summation,
     the order in which we add values should matter less than the naive
     version. *)
  let permutations = 10 in
  let module Fs = Set.Make(struct type t = float let compare = compare end) in
  add_random_test
    ~title:"sumf is better than default"
    Gen.(fixed_length_array 25 (bfloat 1e15))
    (fun arr ->
       let copy = false in
       let nsum = Array.fold_left (+.) 0. in
       let vals = Array.init permutations (fun _ ->
           let sum_me = permute ~copy arr in
           nsum sum_me, sumf sum_me)
       in
       let naive_sums, kahan_sums = Array.unzip vals in
       let make_set   = Array.fold_left (fun s e -> Fs.add e s) Fs.empty in
       let uniq_naive = make_set naive_sums |> Fs.cardinal in
       let uniq_kahan = make_set kahan_sums |> Fs.cardinal in
       (*Printf.printf "naive %d \t kahan %d \n" uniq_naive uniq_kahan; *)
       uniq_kahan <= uniq_naive)
    Spec.([just_postcond_pred is_true]);

  ()
