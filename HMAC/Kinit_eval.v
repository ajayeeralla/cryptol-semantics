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
Require Import BuiltinSyntax.
Require Import Values.        
Require Import Bitstream.
Require Import GlobalExtends.

Require Import EvalTac.
Require Import Eager.

Import HaskellListNotations.
Open Scope string.

Require Import HMAC.

Require Import HMAC_spec.

Require Import HMAC_lib.


Lemma kinit_eval :
  forall GE TE SE,
    wf_env ge GE TE SE ->
    forall (key : ext_val) keylen,
      has_type key (bytestream keylen) ->
      forall h hf,
        good_hash h GE TE SE hf ->
        forall digest t1 t2 t3 kexpr,
          eager_eval_type GE TE t1 (tnum (Z.of_nat keylen)) ->
          eager_eval_type GE TE t2 (tnum (Z.of_nat keylen)) ->
          eager_eval_type GE TE t3 (tnum digest) ->
          eager_eval_expr GE TE SE kexpr (to_sval key) ->
          eager_eval_expr GE TE SE (apply (tapply (EVar kinit) (ETyp t1 :: ETyp t2 :: ETyp t3 ::  nil)) (h :: kexpr :: nil)) (to_sval key).
Proof.
  intros.
  eapply good_hash_eval in H1. do 4 destruct H1.

  
  unfold bytestream in H0. inversion H0. subst.
  gen_global (0,"demote").
  gen_global (14,">").
  gen_global (61,"take").
  gen_global (34,"#").
  gen_global (29,"zero").
  gen_global (35,"splitAt").
  
  e. e. e. e. e.
  gen_global kinit.
  ag.
  e. e. e. e. 
  e. 
  e. e. e. e.

  ag. 
  
  e. e. e. e.
  ag.

  e. e. e.

  reflexivity. e. e. e.

  ag.

  e. e. e.
  reflexivity.
  e. lv. lv.
  simpl. unfold strictnum.

  rewrite gt_not_refl; reflexivity.
  simpl.


  
  e. e. e. e.

  ag. 
  e. e. e. e. e. e. e. e. e.


  ag.

  e. e. e. e. lv. e. e.
  ag.

  e. e.
  reflexivity. e.
  lv. lv.

  unfold to_sval. fold to_sval.
  rewrite append_strict_list. 
  reflexivity.

  e. g. e. g. e. e. e. e.
  ag.

  e. e. e. e. lv. e.
  lv. 
  erewrite <- map_length.
  rewrite splitAt_len. reflexivity.  

  simpl. reflexivity.
Qed.

