Require Import List.
Import ListNotations.
Require Import String.

(* Borrow from CompCert *)
Require Import Coqlib.
Require Import Bitvectors.

Require Import AST.
Require Import Semantics.
Require Import Utils.
Require Import Builtins.
Require Import BuiltinSem.
Require Import Values.        

Require Import EvalTac.

Import HaskellListNotations.
Open Scope string.

Require Import SplitAt.

Lemma eval_c :
  exists v,
    eval_expr ge empty (EVar c) v /\ force_list ge empty v (@from_bitv 8 (@repr 8 3)).
Proof.
  eexists. split.
  e. e. e. e. e. e. g.
  e. e. e. e. e. e. e. e. e. e. e. e. e. g.
  e. e. e. e. g.
  e. e. e. e. e. e.
  e. e. e. e. e. e. g.
  repeat e. e. e. e. e. e. e. e.
  e. e. e. e. reflexivity.

  e. e. e. g.
  e. e. e. e. e. e. e.
  e. e. e. e.
  e. e. e.
  instantiate (2 := O). reflexivity.
  e. e. 

  repeat e.
Qed.
