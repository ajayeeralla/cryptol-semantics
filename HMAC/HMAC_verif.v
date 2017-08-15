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
Require Import Lib.
Require Import GlobalExtends.
Require Import GetEachN.

Require Import EvalTac.
Require Import Eager.

Import HaskellListNotations.
Open Scope string.

Require Import HMAC.

Require Import HMAC_spec.

Require Import HMAC_lib.

Require Import Kinit_eval.

Ltac ec := econstructor; try unfold mb; try reflexivity.
Ltac fg := eapply eager_eval_global_var; [ reflexivity | eassumption | idtac].
Ltac g := eapply eager_eval_global_var; try eassumption; try reflexivity.

Ltac et :=
  match goal with
  | [ |- eager_eval_type _ _ _ _ ] => solve [repeat econstructor; eauto]
  | [ |- Forall2 (eager_eval_type _ _) _ _ ] => econstructor; try et
  end.

Ltac ag := eapply eager_eval_global_var;
           [simpl; unfold extend; simpl; eapply wf_env_not_local; eauto; reflexivity |
            simpl; unfold extend; simpl; eapply wf_env_global; eauto; simpl; reflexivity |
            idtac].

(* solve completely, or leave only 1 subgoal *)
(* fail if running T generates too many subgoals *)
Ltac solve_1 T :=
  first [ ( T; [ idtac ]) ||
          solve [T]].

Ltac lv := eapply eager_eval_local_var; try reflexivity.

(*            | [ |- eager_eval_expr ?GE _ ?E (EVar ?id) _ ] => solve_1 ag
            | [ |- eager_eval_expr ?GE _ ?E (EVar ?id) _ ] => solve_1 fg
            | [ |- eager_eval_expr ?GE _ ?E (EVar ?id) _ ] => solve_1 lv*)

Ltac e :=
  progress (match goal with
            | [ |- eager_eval_expr _ _ _ ?EXPR _ ] =>
              match EXPR with
              | EVar _ => fail 3 "can't handle variables"
              | _ => ec
              end
            end; try eassumption; try et).


Ltac abstract_globals ge :=
  repeat match goal with
         | [ H : ge _ = _ |- _ ] => eapply wf_env_global in H; eauto
         end.

Ltac init_globals global_env :=
  assert (Hdemote : global_env (0, "demote") = Some (mb 2 0 Demote)) by reflexivity;
  assert (Hplus : global_env (1,"+") = Some (mb 1 2 Plus)) by reflexivity;
  assert (Htrue : global_env (9, "True") = Some (mb 0 0 true_builtin)) by reflexivity;
  assert (Hfalse : global_env (10, "False") = Some (mb 0 0 false_builtin)) by reflexivity;
  assert (Hgt : global_env (14,">") = Some (mb 1 2 Gt)) by reflexivity;
  assert (Hxor : global_env (28,"^") = Some (mb 1 2 Xor)) by reflexivity;
  assert (Hat : global_env (40, "@") = Some (mb 3 2 At)) by reflexivity;
  assert (Hsplit : global_env (37,"split") = Some (mb 3 1 split)) by reflexivity;
  assert (HsplitAt : global_env (35,"splitAt") = Some (mb 3 1 splitAt)) by reflexivity;
  assert (Hzero : global_env (29,"zero") = Some (mb 1 0 Zero)) by reflexivity;
  assert (HAppend : global_env (34,"#") = Some (mb 3 2 Append)) by reflexivity.


Ltac e' := e; match goal with
              | [ |- context[eager_eval_type] ] => repeat e
              | [ |- _ ] => idtac
              end.

Ltac break_exists :=
  match goal with
  | [ H : exists _, _ |- _ ] => destruct H
  end.

Ltac break_and :=
  match goal with
  | [ H : _ /\ _ |- _ ] => destruct H
  end.

Ltac break :=
  progress (try break_exists; try break_and).

(* lemma for when the length of the key is the same as the length of the block *)
Lemma Hmac_eval_keylen_is_blocklength :
  forall (key : ext_val) keylen,
    has_type key (bytestream keylen) -> 
    forall GE TE SE, 
      wf_env ge GE TE SE ->
      (forall id, In id [(371, "ks");(372, "okey");(373, "ikey");(374, "internal")] -> GE id = None) ->
      forall h hf,
        good_hash h GE TE SE hf ->
        forall msg msglen unused,
          has_type msg (bytestream msglen) ->
          exists v,
            eager_eval_expr GE TE SE (apply (tapply (EVar hmac) ((typenum (Z.of_nat msglen)) :: (typenum (Z.of_nat keylen)) :: (typenum unused) :: (typenum (Z.of_nat keylen)) :: nil)) (h :: h :: h :: (EValue key) :: (EValue msg) :: nil)) (to_sval v) /\ hmac_model hf key msg = Some v.
Proof.
  intros.
  rename H into Hkeytype.
  rename H1 into HIDs.
  rename H2 into Hgood_hash.
  rename H3 into Hmsgtype.
  init_globals ge.
  abstract_globals ge.
  edestruct good_hash_complete_eval; eauto.
  repeat break.

  inversion Hkeytype. subst.
  inversion Hmsgtype. subst.
  remember (hf (eseq (map (fun x3 : ext_val => xor_const 54 x3) l ++ l0))) as hv1.
  assert (HT : exists n, has_type hv1 (tseq n tbit)). {
    assert (exists n, has_type (eseq (map (fun x3 : ext_val => xor_const 54 x3) l ++ l0)) (bytestream n)). {
      eexists. econstructor.
      rewrite Forall_app. split.
      eapply Forall_map. eauto.
      intros. eapply xor_const_byte; eauto.
      eauto.
    }
    break_exists.
    eapply H1 in H2.
    repeat break. subst. eauto.
  }
  break_exists.
  edestruct ext_val_list_of_strictval; try eassumption.
  
  eexists; split.
  
  e. e. e. e. e. e. e. e. e.
  ag.
  
  e.
  e.
  e.
  e.
  e. e.
  e.
  e.
  e.
  e.
  e.

  e.
  e. 
  lv.
  e. e. e. e. e. 
  
  ag. 

  e. e.
  e. e.

  g.
  e.

  (* evaluate the match *)
  econstructor. econstructor.

  g.

  (* call Kinit function *)
  (* START *)
  {
    eapply kinit_eval.

    unfold bind_decl_groups.
    unfold erase_decl_groups.

    repeat eapply wf_env_extend_TE.
    repeat eapply wf_env_erase_SE.
    repeat eapply wf_env_extend_SE.
    repeat eapply wf_env_extend_GE.
    eassumption.

    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    reflexivity.
    exact Hkeytype.
    
    eapply good_hash_same_eval; eauto.
    repeat (match goal with
            | [ |- global_extends ?X ?X ] => eapply global_extends_refl
            | [ |- global_extends _ _ ] => eapply global_extends_extend_r; eauto
            | [ |- _ ] => idtac
            end);
      try (eapply wf_env_name_irrel_GE; eauto).

    eapply HIDs. simpl. left. reflexivity.
    eapply HIDs. simpl. right. left. reflexivity.
    eapply HIDs. simpl. right. right. left. reflexivity.
    eapply HIDs. simpl. right. right. right. left. reflexivity.

    lv.
    et. et. et.
    lv.
  }  (* END *)
  
  simpl.
  rewrite list_of_strictval_of_strictlist. 
  reflexivity.
  
  (* Begin model section *)
  {
    eapply eager_eval_bind_senvs. eassumption.
    instantiate (1 := fun x => to_sval (xor_const 92 x)).  
    intros. e. e. e. g. unfold extend. simpl.
    eapply wf_env_not_local; eauto. reflexivity.
    e. e. lv. e. e. e. ag.
    e. repeat e. repeat e.
    econstructor; try et.
    reflexivity.
    e. econstructor.
    lv. econstructor.
    lv. econstructor.
    simpl. 
    inversion H6. subst. simpl.
    unfold strictnum.
    unfold Z.to_nat. unfold Pos.to_nat.
    unfold Pos.iter_op. unfold Init.Nat.add.
    rewrite xor_num. reflexivity.
    rewrite H7. eassumption.
    congruence.
  }
  (* End model section *)

  e. g.
  e. e. e. e. g.
  simpl. unfold extend. simpl. eapply wf_env_not_local; eauto.
  reflexivity.
  e. e. e. e. e. lv. e. e. e. e. e. g.
  simpl. unfold extend. simpl. eapply wf_env_not_local; eauto.
  reflexivity.
  e. e. e. e. g.
  e. ec. ec.
  g.
  {
    eapply kinit_eval.

    unfold bind_decl_groups.
    unfold erase_decl_groups.
    repeat eapply wf_env_extend_GE.
    repeat eapply wf_env_extend_TE.
    repeat eapply wf_env_erase_SE.
    repeat eapply wf_env_extend_SE.
    assumption.

    all: try solve [reflexivity].

    exact Hkeytype.

    eapply good_hash_same_eval; eauto.
    repeat (match goal with
            | [ |- global_extends ?X ?X ] => eapply global_extends_refl
            | [ |- global_extends _ _ ] => eapply global_extends_extend_r; eauto
            | [ |- _ ] => idtac
            end);
      try (eapply wf_env_name_irrel_GE; eauto).

    eapply HIDs. simpl. left. reflexivity.
    eapply HIDs. simpl. right. left. reflexivity.
    eapply HIDs. simpl. right. right. left. reflexivity.
    eapply HIDs. simpl. right. right. right. left. reflexivity.
    lv. et. et. et.
    lv.
  }
  simpl.
  rewrite list_of_strictval_of_strictlist. 
  reflexivity.

  eapply eager_eval_bind_senvs. eassumption.
  instantiate (1 := fun x => to_sval (xor_const 54 x)).  
  intros. e. e. e. g. unfold extend. simpl.
  eapply wf_env_not_local; eauto. reflexivity.
  e. e. lv. e. e. e. g. 
  unfold extend. simpl.
  eapply wf_env_not_local; eauto. reflexivity.
  e. e. e. ec. reflexivity.
  e. ec. lv. ec. lv. ec.
  inversion H6. subst. simpl.
  unfold strictnum.
  rewrite xor_num. reflexivity.
  rewrite H7. eassumption.
  simpl. unfold Pos.to_nat. simpl. congruence.

  e. lv. e. ec. lv. ec. lv. ec.

  unfold to_sval. fold to_sval.  
  rewrite append_strict_list. 
  reflexivity.

  eapply global_extends_eager_eval.

  replace (map (fun x3 : ext_val => to_sval (xor_const 54 x3)) l) with
      (map to_sval (map (fun x3 => xor_const 54 x3) l)) by (rewrite list_map_compose; reflexivity).
  rewrite <- list_append_map.
  remember (app (map (fun x3 : ext_val => xor_const 54 x3) l) l0) as ll.
  replace (strict_list (map to_sval ll)) with (to_sval (eseq ll)) by (reflexivity).
  subst ll.
  
  eapply H1.
  econstructor.

  rewrite Forall_app. split; auto.
  eapply Forall_map. eassumption.

  intros. eapply xor_const_byte; eauto.

  unfold bind_decl_groups.
  unfold bind_decl_group.
  unfold declare.


  repeat (match goal with
          | [ |- global_extends ?X ?X ] => eapply global_extends_refl
          | [ |- global_extends _ _ ] => eapply global_extends_extend_r; eauto
          | [ |- _ ] => idtac
          end);
    try (eapply wf_env_name_irrel_GE; eauto).

  eapply HIDs. simpl. left. reflexivity.
  eapply HIDs. simpl. right. left. reflexivity.
  eapply HIDs. simpl. right. right. left. reflexivity.
  eapply HIDs. simpl. right. right. right. left. reflexivity.
  
  e. ec. lv. ec. 

  simpl.
  rewrite <- Heqhv1.
  rewrite H3. reflexivity.
  
  e. ec. lv. ec. lv. ec.

  rewrite append_strict_list. reflexivity.
  eapply global_extends_eager_eval.

  (* get to_sval out to outside *)
  (* evaluate the hash function *)

  replace (map (fun x4 : ext_val => to_sval (xor_const 92 x4)) l) with
  (map to_sval (map (xor_const 92) l)) by
      (clear -l; 
       induction l; simpl; auto; f_equal; eapply IHl; eauto).
    
  rewrite get_each_n_map_commutes.


  rewrite map_strict_list_map_map_to_sval.
  rewrite <- list_append_map.
  rewrite strict_list_map_to_sval.

  (* This one will be some fun *)
  assert (exists n, has_type (eseq (map (xor_const 92) l ++ map eseq (get_each_n (Pos.to_nat 8) x4))) (bytestream n)). {

    eapply has_type_seq_append.
    exists (Datatypes.length (map (xor_const 92) l)).
    econstructor.
    eapply Forall_map. eassumption.
    intros. eapply xor_const_byte; eauto.
    subst hv1.
    inversion H2. subst.
    rewrite <- H6 in *.
    eapply list_of_strictval_to_sval in H3. inversion H3.
    subst. 
    remember H1 as HHash.
    clear HeqHHash.
    symmetry in H6.    
    eapply good_hash_fully_padded in H6; try eassumption.
    eapply type_stream_of_bytes in H6; eauto.
    
  }

  break_exists.
  eapply H1 in H6. break_and. eassumption.
  
  repeat (match goal with
          | [ |- global_extends ?X ?X ] => eapply global_extends_refl
          | [ |- global_extends _ _ ] => eapply global_extends_extend_r; eauto
          | [ |- _ ] => idtac
          end);
    try (eapply wf_env_name_irrel_GE; eauto).
  
  eapply HIDs. simpl. left. reflexivity.
  eapply HIDs. simpl. right. left. reflexivity.
  eapply HIDs. simpl. right. right. left. reflexivity.
  eapply HIDs. simpl. right. right. right. left. reflexivity.


  (* our result matches the model *)
  subst hv1.
  eapply list_of_strictval_to_sval in H3.
  simpl. rewrite H3.

  reflexivity.

  Unshelve.
  all: exact id.
  
Qed.
