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
open Online
module D = Statistics.Descriptive

(* In order for these tests to work well, we have to span the range of
   acceptable floats as well. If we're uniformly sampling from [0, largest_float]
   we'll have different characteristics if largest_float is tiny or huge:
   this will influence the significand in the algorithms.
*)

let () =
  let add_random_test
    ?title ?nb_runs ?nb_tries ?classifier
    ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec =
    Test.add_random_test_group "Running"
      ?title ?nb_runs ?nb_tries ?classifier
      ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec
  in
  let max_array_size = 10000 in (* tested up to 100000 *)
  let not_degenerate rs =
    not (is_degenerate rs.last) &&
    not (is_degenerate rs.max) &&
    not (is_degenerate rs.min) &&
    not (is_degenerate rs.sum) &&
    not (is_degenerate rs.sum_sq) &&
    not (is_degenerate rs.mean) &&
    not (is_degenerate rs.var)
  in
  let roughly_equal ~order_comp x y =
    let d = (D.geometric_mean [|x; y|]) /. order_comp in
    not (significantly_different_from ~d x y)
    in
  let compare_against_descriptive rs data =
    let n = Array.length data in
    let dv = D.var ~biased:false data in
    let ds = data |> Array.map (fun x-> x *. x) |> Array.sumf in
    (*Printf.printf "%f vs %f \n" rs.sum_sq ds; *)
    rs.size = n &&
    equal_floats ~d:dx rs.last data.(n - 1) &&
    equal_floats ~d:dx rs.max (Array.max data) &&
    equal_floats ~d:dx rs.min (Array.min data)  &&
    equal_floats ~d:(dx*.1e14) rs.sum (Array.sumf data) &&
    roughly_equal ~order_comp:1e14 rs.sum_sq ds &&
    equal_floats ~d:(dx*.1e10) rs.mean (D.mean data) &&
    roughly_equal ~order_comp:1e13 rs.var dv
  in
  let compare_rs rs1 rs2 =
    (* Printf.printf "[mean] %f vs %f \n" rs1.mean rs2.mean; *)
    (* Printf.printf "[var] %f vs %f \n" rs1.var rs2.var; *)
    rs1.size = rs2.size &&
    equal_floats ~d:dx rs1.last rs2.last &&
    equal_floats ~d:dx rs1.max rs2.max &&
    equal_floats ~d:dx rs1.min rs2.min &&
    equal_floats ~d:(dx*.1e14) rs1.sum rs2.sum &&
    roughly_equal ~order_comp:1e13 rs1.sum_sq rs2.sum_sq &&
    equal_floats ~d:(dx*.1e13) rs1.mean rs2.mean &&
    roughly_equal ~order_comp:1e13 rs1.var rs2.var
  in
  add_random_test
    ~title:"Analysis is not degenerate."
    ~nb_runs:1000
    Gen.(array (make_int 1 max_array_size) (bfloat 1e10))
    (fun data ->
      let n = Array.length data in
      let rs1 = Array.fold_left update empty data in
      let rs2 = Array.fold_left update (init data.(0))
                  (Array.sub data 1 (n - 1))
      in
      not_degenerate rs1 && not_degenerate rs2)
      Spec.([just_postcond_pred is_true]);

  add_random_test
    ~title:"Works as well as Descriptive."
    (* This is really a test of Descriptive ...  as the point of Running is to
       be more accurate. How to encode the higher accuracy though? We're
       essentially comparing the difference between the two. *)
    ~nb_runs:1000
    Gen.(array (make_int 1 max_array_size) (bfloat 1e10))
    (fun data ->
      let n = Array.length data in
      let rs1 = Array.fold_left update empty data in
      let rs2 = Array.fold_left update (init data.(0))
                  (Array.sub data 1 (n - 1))
      in
      compare_against_descriptive rs1 data &&
      compare_against_descriptive rs2 data)
      Spec.([just_postcond_pred is_true]);

  add_random_test
    ~title:"We can also join!"
    ~nb_runs:1000
    Gen.(zip2 (make_int 1 max_array_size) (barray_float 1e10 max_array_size))
    (fun (index, data) ->
      let left  = Array.sub data 0 index
      and right = Array.sub data index (Array.length data - index) in
      let rs_left   = Array.fold_left update empty left
      and rs_right  = Array.fold_left update empty right in
      let rs_data   = Array.fold_left update empty data in
      let rs_joined = join rs_left rs_right in
      compare_rs rs_data rs_joined)
    Spec.([just_postcond_pred is_true]);

  add_random_test
    ~title:"Variable sizes using update"
    ~nb_runs:1000
    Gen.(barray_float 1e10 10)
    (fun data ->
      let first = Array.fold_left update empty data in
      let second = Array.fold_left update first data in
      let twice = Array.fold_left (update ~size:2) empty data in
      compare_rs second twice)
    Spec.([just_postcond_pred is_true]);

  ()
