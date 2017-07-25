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
Require Import Eager.
Require Import Bitstream.

Require Import EvalTac.

Import HaskellListNotations.
Open Scope string.

Require Import HMAC.

Require Import HMAC_spec.

Require Import HMAC_lib.

Require Import Kinit_eval2.

(* Now we can use ext_val to characterize the inputs to HMAC *)
(* As well, we can simply write HMAC over ext_val *)

(* Model of hmac, given model of hash *)
Definition hmac_model (hf : ext_val -> ext_val) (key msg : ext_val) : option ext_val := None. (* TODO *)

Lemma eager_eval_bind_senvs :
  forall l model GE TE exp SE id,
    (Forall (fun x => has_type x byte) l) ->
    (forall ev, has_type ev byte -> eager_eval_expr GE TE (extend SE id (to_sval ev)) exp (model ev)) ->
    Forall2 (fun se => eager_eval_expr GE TE se exp)
            (bind_senvs SE (map (fun sv => [(id,sv)]) (map to_sval l))) (map model l).
Proof.
  induction l; intros.
  econstructor; eauto.
  
  inversion H. subst.
  eapply IHl in H4.
  simpl. econstructor; [idtac | eassumption].
  eapply H0. eauto.
  intros. eapply H0. eauto.
Qed.

Fixpoint xor_const_list (idx : Z) (const : Z) (l : list ext_val) : list ext_val :=
  match l with
  | nil => nil
  | (ebit b) :: r =>
    let r' := xor_const_list (idx - 1) const r in
    let b' := Z.testbit const idx in
    (ebit (xorb b b')) :: r'
  | _ => nil
  end.

Definition xor_const (const : Z) (e : ext_val) : ext_val :=
  match e with
  | eseq l => eseq (xor_const_list ((Z.of_nat ((Datatypes.length l)) - 1)) const l)
  | _ => ebit false
  end.

Lemma strictval_from_bitv'_widen :
  forall a b n z,
    (a >= n)%nat ->
    (b >= n)%nat ->
    strictval_from_bitv' a n (@repr a z) = strictval_from_bitv' b n (@repr b z).
Proof.
  induction n; intros.
  simpl. reflexivity.

  simpl.
  f_equal. f_equal.
  assert (Z.of_nat (S n) > Z.of_nat n).
  simpl. rewrite Zpos_P_of_succ_nat. omega.
  erewrite testbit_widen.
  symmetry.
  erewrite testbit_widen.
  reflexivity.
  eassumption.
  assumption.
  eassumption.
  assumption.
  eapply IHn; eauto; omega.
Qed.

Lemma strictval_from_bitv_norm :
  forall x n z,
    (x >= n)%nat ->
    strictval_from_bitv' x n (@repr x z) = strictval_from_bitv' n n (@repr n z).
Proof.
  intros.
  erewrite strictval_from_bitv'_widen; eauto.
Qed.

Lemma testbit_unsigned_repr :
  forall w z idx,
    Z.of_nat w > idx ->
    Z.testbit (@unsigned w (@repr w z)) idx = Z.testbit z idx.
Proof.
  induction w; intros;
    simpl.
  * assert (idx < 0) by (simpl in H; omega).
    destruct idx; simpl in H0; try omega.
    remember (Zgt_pos_0 p) as HH. omega.
    simpl. reflexivity.
  * rewrite Z_mod_modulus_eq; try omega.
    unfold modulus.
    rewrite two_power_nat_equiv.
    rewrite Z.mod_pow2_bits_low;
      try omega.
    reflexivity.
Qed.

Lemma length_cons :
  forall {A} (e : A) l,
    Datatypes.length (e :: l) = S (Datatypes.length l).
Proof.
  reflexivity.
Qed.

Lemma map_cons :
  forall {A B} (f : A -> B) (e : A) l,
    map f (e :: l) = (f e) :: (map f l).
Proof.
  reflexivity.
Qed.

Lemma succ_nat_pred :
  forall n,
    (Z.of_nat (S n)) - 1 = Z.of_nat n.
Proof.
  intros.
  repeat rewrite Nat2Z.inj_succ.
  omega.
Qed.


(* we can tweak xor_const to make this true *)
Lemma xor_num :
  forall  l n z,
    has_type (eseq l) (tseq (Datatypes.length l) tbit) ->
    n = Datatypes.length l ->
    xor_sem (strict_list (map to_sval l)) (strict_list (strictval_from_bitv (@repr n z))) = Some (to_sval (xor_const z (eseq l))).
Proof.
  induction l; intros.
  simpl in *.
  unfold strictval_from_bitv. subst n.
  simpl. reflexivity.

  assert (has_type (eseq l) (tseq (Datatypes.length l) tbit)).
  {
    inversion H. econstructor; eauto. inversion H3. auto.
    
  }
  inversion H. subst.
  inversion H4. subst.
  inversion H3. subst.
  
  unfold strictval_from_bitv in *.
  unfold strictval_from_bitv'. fold strictval_from_bitv'.
  repeat rewrite length_cons.
  repeat rewrite map_cons.
  unfold strict_list. fold strict_list.
  unfold to_sval at 1.   unfold xor_sem. fold xor_sem.
  unfold strictval_from_bitv'. fold strictval_from_bitv'.
  unfold strict_list. fold strict_list.
  
  repeat rewrite strictval_from_bitv_norm by (eauto; try omega).
  repeat match goal with
         | [ |- context[(Z.of_nat (?X - 0))] ] => 
           replace (X - 0)%nat with X by omega
         end.
  rewrite IHl; eauto.
  f_equal.
  unfold xor_const. rewrite length_cons.
  unfold xor_const_list.
  fold xor_const_list.
  unfold to_sval.
  unfold strict_list.
  fold strict_list.
  fold to_sval.
  rewrite map_cons.
  unfold strict_list.
  fold strict_list.
  repeat rewrite succ_nat_pred.
  f_equal.
  
  unfold xorb.
  unfold testbit.
  rewrite testbit_unsigned_repr by (simpl; rewrite Zpos_P_of_succ_nat; omega).
  destruct b; try reflexivity.
  destruct (Z.testbit z (Z.of_nat (Datatypes.length l))); reflexivity.
Qed.


Lemma Forall_app :
  forall {A} (l1 l2 : list A) P,
    Forall P (l1 ++ l2) <-> Forall P l1 /\ Forall P l2.
Proof.
  induction l1; intros; split; intros; simpl; auto.
  destruct H. auto.
  simpl in H. inversion H. subst.
  rewrite IHl1 in H3.
  destruct H3. split.
  econstructor; eauto.
  eauto.
  destruct H. inversion H. econstructor; eauto.
  rewrite IHl1. split; eauto.
Qed.

Lemma Forall_map :
  forall {A} (l : list A) P f,
    Forall P l ->
    (forall x, P x -> P (f x)) ->
    Forall P (map f l).
Proof.
  induction 1; intros; simpl; auto.
Qed.



(* lemma for when the length of the key is the same as the length of the block *)
Lemma Hmac_eval_keylen_is_blocklength :
  forall (key : ext_val) keylen,
    has_type key (bytestream keylen) -> 
    forall GE TE SE, 
      wf_env ge GE TE SE ->
      forall h hf,
        good_hash h GE TE SE hf ->
        forall msg msglen unused,
          has_type msg (bytestream msglen) ->
          exists v,
            eager_eval_expr GE TE SE (apply (tapply (EVar hmac) ((typenum (Z.of_nat msglen)) :: (typenum (Z.of_nat keylen)) :: (typenum unused) :: (typenum (Z.of_nat keylen)) :: nil)) (h :: h :: h :: (EValue (to_val key)) :: (EValue (to_val msg)) :: nil)) (to_sval v) /\ hmac_model hf key msg = Some v.
Proof.
  intros.
  init_globals ge.
  abstract_globals ge.
  edestruct good_hash_complete_eval; eauto.
  do 4 destruct H3.

  inversion H. subst.
  inversion H2. subst.

  eexists; split.

  e. e. e. e. e. e. e. e. e.
  ag.

  e. e. e. e. e.
  eassumption.
  e. eassumption.
  e. eassumption.
  e. e.

  eapply strict_eval_val_to_val.

  e. e.
  eapply strict_eval_val_to_val.

  e. e. e. e. e. e. e. e.
  g. simpl. unfold extend. simpl.
  eapply wf_env_not_local; eauto.
  reflexivity.

  e.
  e. e. e.
  eapply eager_eval_global_var.
  reflexivity.
  reflexivity.
  e. e. e. eapply eager_eval_global_var.
  reflexivity.
  reflexivity.

  
  eapply kinit_eval.
  admit. (* extend env is wf_env *)
  exact H.
  admit. (* hash is a good hash in extended environment *)

  repeat e. repeat e.
  repeat e. e.
  
  simpl.
  rewrite list_of_strictval_of_strictlist. 
  reflexivity.
  
  (* Begin model section *)
  eapply eager_eval_bind_senvs. eassumption.
  instantiate (1 := fun x => to_sval (xor_const 92 x)).  
  intros. e. e. e. g. unfold extend. simpl.
  eapply wf_env_not_local; eauto. reflexivity.
  e. e. e. e. e. e. g.
  unfold extend. simpl.
  eapply wf_env_not_local; eauto. reflexivity.
  e. repeat e. repeat e. e. repeat e.
  repeat e. simpl.
  inversion H5. subst. simpl.
  unfold strictnum.
  unfold Z.to_nat. unfold Pos.to_nat.
  unfold Pos.iter_op. unfold Init.Nat.add.
  rewrite <- H6.
  rewrite xor_num. reflexivity.
  rewrite H6. eassumption.
  reflexivity.
  (* End model section *)

  e. g.
  e. e. e. e. g.
  simpl. unfold extend. simpl. eapply wf_env_not_local; eauto.
  reflexivity.
  e. e. e. e. e. e. e. e. e. e. e. g.
  simpl. unfold extend. simpl. eapply wf_env_not_local; eauto.
  reflexivity.
  e. e. e. e. g.
  e. e. e. g.
  eapply kinit_eval.
  admit. exact H.
  admit. repeat e.
  repeat e. repeat e. e.

  simpl.
  rewrite list_of_strictval_of_strictlist. 
  reflexivity.


  eapply eager_eval_bind_senvs. eassumption.
  instantiate (1 := fun x => to_sval (xor_const 54 x)).  
  intros. e. e. e. g. unfold extend. simpl.
  eapply wf_env_not_local; eauto. reflexivity.
  e. e. e. e. e. e. g.
  unfold extend. simpl.
  eapply wf_env_not_local; eauto. reflexivity.
  e. repeat e. repeat e. e. repeat e.
  repeat e. simpl.
  inversion H5. subst. simpl.
  unfold strictnum.
  unfold Z.to_nat. unfold Pos.to_nat.
  unfold Pos.iter_op. unfold Init.Nat.add.
  rewrite <- H6.
  rewrite xor_num. reflexivity.
  rewrite H6. eassumption.
  reflexivity.

  e. e. e. repeat e.
  repeat e.
  
  unfold to_sval. fold to_sval.
  rewrite append_strict_list. 
  reflexivity.

  eapply global_extends_eager_eval.

  (* TODO: get to_sval to the outside *)

  replace (map (fun x3 : ext_val => to_sval (xor_const 54 x3)) l) with
      (map to_sval (map (fun x3 => xor_const 54 x3) l)) by (rewrite list_map_compose; reflexivity).
  rewrite <- list_append_map.
  remember (app (map (fun x3 : ext_val => xor_const 54 x3) l) l0) as ll.
  replace (strict_list (map to_sval ll)) with (to_sval (eseq ll)) by (reflexivity).
  subst ll.
  eapply H4.
  econstructor.

  rewrite Forall_app. split; auto.
  eapply Forall_map. eassumption.
  admit. (* xor_const preserves type *)

  admit. (* extended global environment *)

  e. repeat e.
  e. e. e.

  (* We need a fact about the hash function that shows its result type *)
  (* We need a fact about splitting things of the right type *)
  simpl.
  remember (hf (eseq (map (fun x3 : ext_val => xor_const 54 x3) l ++ l0))) as hv1.
  
  assert (exists n, has_type hv1 (tseq n tbit)) by admit.
  destruct H5.

  
  admit. (* split things *)

  e. repeat e. repeat e.
  
  admit. (* append *)
  
  
  (* evaluate the hash function *)
  admit.

  (* our result matches the model *)
  admit.
  
Admitted.
