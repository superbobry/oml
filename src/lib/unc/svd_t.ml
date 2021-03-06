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
open Lacaml.D
module Svd = Uncategorized.Svd
module Matrices = Uncategorized.Matrices
module Vectors = Uncategorized.Vectors

let () =
  let add_partial_random_test
    ?title ?nb_runs ?nb_tries ?classifier
    ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec =
    Test.add_partial_random_test_group "Svd"
      ?title ?nb_runs ?nb_tries ?classifier
      ?reducer ?reduce_depth ?reduce_smaller ?random_src gen f spec
  in
  let max_matrix_size = 10 in
  (*let at_least_as_man_rows_as_columns m =
    let r, c = Matrices.dim m in
    r >= c
  in*)
  add_partial_random_test
    ~title:"We can."
    Gen.(matrix (make_int 1 4) (make_int 1 5) (bfloat 1e6))
    (fun a ->
      let open Lacaml.D in
      let t = Svd.svd (Mat.of_array a) in
      let a_rec = Matrices.(prod (prod (Svd.u t) (diagonal (Svd.s t))) (Svd.vt t)) in
      Matrices.equal ~d:(Util.dx *. 1e9) a a_rec)
    Spec.([ (*at_least_as_man_rows_as_columns ==> is_result is_true *)
          always ==> is_result is_true]);

  let vectors_about_equal (b1, b2) = Vectors.equal ~d:0.1 b1 b2 in
  add_partial_random_test
    ~title:"Can find a solution to linear problems."
    Gen.(matrix (make_int 3 max_matrix_size) (make_int 3 max_matrix_size) (bfloat 1e6))
    (fun m ->
      let x = m.(0) in
      let a = Array.sub m 1 (Array.length m - 1) in
      let b = Matrices.prod_column_vector a x in
      let t = Svd.svd (Mat.of_array a) in
      let y = Svd.solve_linear t (Vec.of_array b) |> Vec.to_array in
      let bc = Matrices.prod_column_vector a y in
      (* Can't compare x and y since they might be different projections,
         especially in just unaligned random data! *)
      (*let (r,c) = Matrices.dim a in
      Printf.printf "---------%d by %d: [%s] -----------\n" r c
        (Vectors.sub b bc |> Array.map string_of_float |> Array.to_list |> String.concat ";"); *)
      (b,bc))
    Spec.([ always ==> is_result vectors_about_equal (*at_least_as_man_rows_as_columns ==> is_result vectors_about_equal
          ; always ==> is_result never*)]);

  ()
