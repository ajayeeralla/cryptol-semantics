Require Import String.
Require Import List.
Import ListNotations.
Require Import Coq.Arith.PeanoNat.

(* Borrow from CompCert *)
Require Import Coqlib.

(*Require Import Integers.*)
Require Import Bitvectors.
Require Import AST.
Require Import Builtins.
Require Import Values.
Require Import BuiltinSem.
Require Import Semantics.

Open Scope list_scope.

Definition match_env (ge : genv) (E : ident -> option val) (SE : ident -> option strictval) : Prop :=
  forall id,
    option_rel (strict_eval_val ge) (E id) (SE id).


Inductive eager_eval_type (ge : genv) : (ident -> option strictval) -> Typ -> Tval -> Prop :=
| eager_eval_tvar_bound :
    forall E uid t k,
      E (uid,""%string) = Some (styp t) -> (* this lookup can be done with any string, as ident_eq only uses uid *)
      eager_eval_type ge E (TVar (TVBound uid k)) t
(* | eager_eval_tvar_free : *)
(* TODO: not sure what to do with free type variables...*)
| eager_eval_trec :
    forall E l lv,
      Forall2 (eager_eval_type ge E) (map snd l) (map snd lv) ->
      map fst l = map fst lv ->
      eager_eval_type ge E (TRec l) (trec lv)
| eager_eval_ttup :
    forall E l lv n,
      Forall2 (eager_eval_type ge E) l lv ->
      n = length l ->
      eager_eval_type ge E (TCon (TC (TCTuple n)) l) (ttup lv)
| eager_eval_tseq :
    forall E l len lenv elem elemv,
      l = len :: elem :: nil ->
      eager_eval_type ge E len lenv ->
      eager_eval_type ge E elem elemv ->
      eager_eval_type ge E (TCon (TC TCSeq) l) (tseq lenv elemv)
| eager_eval_tnum :
    forall E n,
      eager_eval_type ge E (TCon (TC (TCNum n)) nil) (tnum n)
| eager_eval_tbit :
    forall E,
      eager_eval_type ge E (TCon (TC TCBit) nil) tbit
| eager_eval_tinf :
    forall E,
      eager_eval_type ge E (TCon (TC TCInf) nil) tinf
| eager_eval_tfunction_type_base :
    forall E a arg r res,
      eager_eval_type ge E a arg ->
      eager_eval_type ge E r res ->
      eager_eval_type ge E (TCon (TC TCFun) (a :: r :: nil)) (tfun arg res)
| eager_eval_tfunction_type_rec :
    forall E a r arg res,
      eager_eval_type ge E a arg ->
      eager_eval_type ge E (TCon (TC TCFun) r) res ->
      eager_eval_type ge E (TCon (TC TCFun) (a :: r)) (tfun arg res)
| eager_eval_type_add :
    forall E l r a b n,
      eager_eval_type ge E l (tnum a) ->
      eager_eval_type ge E r (tnum b) ->
      n = a + b ->
      eager_eval_type ge E (TCon (TF TCAdd) (l :: r :: nil)) (tnum n)
| eager_eval_type_sub :
    forall E l r a b n,
      eager_eval_type ge E l (tnum a) ->
      eager_eval_type ge E r (tnum b) ->
      n = a - b ->
      eager_eval_type ge E (TCon (TF TCSub) (l :: r :: nil)) (tnum n)
| eager_eval_type_mul :
    forall E l r a b n,
      eager_eval_type ge E l (tnum a) ->
      eager_eval_type ge E r (tnum b) ->
      n = a * b ->
      eager_eval_type ge E (TCon (TF TCMul) (l :: r :: nil)) (tnum n)
| eager_eval_type_div :
    forall E l r a b n,
      eager_eval_type ge E l (tnum a) ->
      eager_eval_type ge E r (tnum b) ->
      b <> 0 ->
      n = a / b ->
      eager_eval_type ge E (TCon (TF TCDiv) (l :: r :: nil)) (tnum n)
| eager_eval_type_mod :
    forall E l r a b n,
      eager_eval_type ge E l (tnum a) ->
      eager_eval_type ge E r (tnum b) ->
      b <> 0 ->
      n = a mod b ->
      eager_eval_type ge E (TCon (TF TCMod) (l :: r :: nil)) (tnum n)
| eager_eval_type_exp :
    forall E l r a b n,
      eager_eval_type ge E l (tnum a) ->
      eager_eval_type ge E r (tnum b) ->
      n = Z.pow a b ->
      eager_eval_type ge E (TCon (TF TCExp) (l :: r :: nil)) (tnum n)
| eager_eval_type_min :
    forall E l r a b n,
      eager_eval_type ge E l (tnum a) ->
      eager_eval_type ge E r (tnum b) ->
      n = Z.min a b ->
      eager_eval_type ge E (TCon (TF TCMin) (l :: r :: nil)) (tnum n)
| eager_eval_type_max :
    forall E l r a b n,
      eager_eval_type ge E l (tnum a) ->
      eager_eval_type ge E r (tnum b) ->
      n = Z.max a b ->
      eager_eval_type ge E (TCon (TF TCMax) (l :: r :: nil)) (tnum n)
| eager_eval_type_width :
    forall E e n,
      eager_eval_type ge E e (tnum n) ->
      eager_eval_type ge E (TCon (TF TCWidth) (e :: nil)) (tnum (calc_width n))
(* | eager_eval_type_len_from_then_to : *)
(* | eager_eval_type_len_from_then : *)
.


Fixpoint list_of_strictval (v : strictval) : option (list strictval) :=
  match v with
  | svnil => Some nil
  | svcons f r =>
    match list_of_strictval r with
    | Some lvr => Some (f :: lvr)
    | _ => None
    end
  | _ => None
  end.

Definition senv := ident -> option strictval.

Fixpoint zipwith {A B C : Type} (f : A -> B -> C) (lA : list A) (lB : list B) : list C :=
  match lA,lB with
  | a :: aa, b :: bb => (f a b) :: zipwith f aa bb
  | _,_ => nil
  end.

Fixpoint foreach {A B C : Type} (f : A -> B -> C) (a : A) (lB : list B) : list C :=
  map (f a) lB.

(* for each element in lA, make a copy of lB and append that element to the front *)
(* cartesian product, in a sense *)
Fixpoint product {A : Type} (lA : list A) (lB : list (list A)) : list (list A) :=
  match lA with
  | nil => nil
  | f :: nil => map (fun x => f :: x) lB
  | f :: r =>
    (map (fun x => f :: x) lB) ++ (product r lB)
  end.

Definition bind_senvs (E : senv) : list (list (ident * strictval)) -> list senv :=
  map (fun lidv => fold_left (fun senv => fun idv => extend senv (fst idv) (snd idv)) lidv E).


Fixpoint xor_sem (a b : strictval) : option strictval :=
  match a,b with
  | (sbit a),(sbit b) => Some (sbit (if a then (if b then false else true) else b))
  | (svcons fa ra), (svcons fb rb) =>
    match xor_sem fa fb, xor_sem ra rb with
    | Some sa, Some sr => Some (svcons sa sr)
    | _,_ => None
    end
  | svnil,svnil => Some svnil
  | _,_ => None
  end.
    
Definition strict_builtin_sem (bi : builtin) (l : list strictval) : option strictval :=
  match bi,l with
  | Xor,(t :: a :: b :: nil) => xor_sem a b
  | _,_ => None
  end.


Inductive eager_eval_expr (ge : genv) : senv -> Expr -> strictval -> Prop :=
| eager_eval_local_var :
    forall E id v,
      E id = Some v ->
      eager_eval_expr ge E (EVar id) v
| eager_eval_global_var :
    forall E id v exp,
      E id = None ->
      ge id = Some exp ->
      eager_eval_expr ge E exp v ->
      eager_eval_expr ge E (EVar id) v
| eager_eval_abs :
    forall E id exp,
      eager_eval_expr ge E (EAbs id exp) (sclose id exp E)
| eager_eval_tabs :
    forall E e id,
      eager_eval_expr ge E (ETAbs id e) (stclose id e E)
| eager_eval_app :
    forall E f id exp E' a av v,
      eager_eval_expr ge E f (sclose id exp E') ->
      eager_eval_expr ge E a av ->
      eager_eval_expr ge (extend E' id av) exp v ->
      eager_eval_expr ge E (EApp f a) v
| eager_eval_tapp :
    forall E e id e' E' v t te,
      eager_eval_expr ge E e (stclose id e' E') ->
      eager_eval_expr ge E te (styp t) -> 
      eager_eval_expr ge (extend E' id (styp t)) e' v ->
      eager_eval_expr ge E (ETApp e te) v
| eager_eval_typ :
    forall E t tv,
      eager_eval_type ge E t tv ->
      eager_eval_expr ge E (ETyp t) (styp tv)
| eager_eval_lazyval :
    forall v sv E,      
      strict_eval_val ge v sv ->
      eager_eval_expr ge E (EValue v) sv
| eager_eval_list :
    forall E l vs v,
      Forall2 (eager_eval_expr ge E) l vs ->
      v = strict_list vs ->
      eager_eval_expr ge E (EList l) v
| eager_eval_comp :
    forall E llm llidv vs v e,
      eager_par_match ge E llm llidv ->
      Forall2 (fun senv => eager_eval_expr ge senv e) (bind_senvs E llidv) vs ->
      v = strict_list vs ->
      eager_eval_expr ge E (EComp e llm) v
| eager_eval_builtin :
    forall E l args bi v,
      Forall2 (eager_eval_expr ge E) l args ->
      strict_builtin_sem bi args = Some v ->
      eager_eval_expr ge E (EBuiltin bi l) v
with eager_par_match (ge : genv) : senv -> list (list Match) -> list (list (ident * strictval)) -> Prop :=
     | eager_par_one :
         forall E lm lidv,
           eager_index_match ge E lm lidv ->
           eager_par_match ge E (lm :: nil) lidv
     | eager_par_more :
         forall E lm lidv lr llidv,
           lr <> nil ->
           eager_index_match ge E lm lidv ->
           eager_par_match ge E lr llidv ->
           eager_par_match ge E (lm :: lr) (zipwith (fun x => fun y => x ++ y) lidv llidv)

(* provide the bound environments for one part of a list comprehension *)
with eager_index_match (ge : genv) : senv -> list Match -> list (list (ident * strictval)) -> Prop :=
     | eager_idx_last :
         forall E e vs lv id,
           eager_eval_expr ge E e vs ->
           list_of_strictval vs = Some lv ->
           eager_index_match ge E ((From id e) :: nil) (map (fun sv => (id,sv) :: nil) lv)
     | eager_idx_mid :
         forall E e vs lv llidv id r,
           r <> nil ->
           eager_eval_expr ge E e vs ->
           list_of_strictval vs = Some lv ->
           eager_index_match ge E r llidv ->
           eager_index_match ge E ((From id e) :: r) (product (map (fun sv => (id,sv)) lv) llidv)
.  

Lemma match_env_none :
  forall ge E SE id,
    match_env ge E SE ->
    (E id = None <-> SE id = None).
Proof.
  split; intros;
    unfold match_env in *;
    specialize (H id);
    rewrite H0 in *; inversion H; auto.
Qed.

Lemma eager_to_strict_lazy_type :
  forall t ge SE tv,
    eager_eval_type ge SE t tv ->
    forall E,
      match_env ge E SE ->
      eval_type ge E t tv.
Proof.
  (* weird Forall2 induction needed *)
Admitted.

Lemma eager_to_strict_lazy :
  forall ge SE exp sv,
    eager_eval_expr ge SE exp sv ->
    forall E,
      match_env ge E SE ->
      strict_eval_expr ge E exp sv.
Proof.
  induction 1; intros.
  - unfold match_env in *.
    specialize (H0 id). rewrite H in H0. inv H0.
    econstructor.
    econstructor; eauto.
    eauto.
  - erewrite <- match_env_none in H by eauto.
    eapply IHeager_eval_expr in H2. inversion H2. subst.
    econstructor. eapply eval_global_var; eauto.
    eassumption.
  - econstructor; eauto. econstructor. econstructor.
    eassumption.
  - econstructor; eauto. econstructor. econstructor.
    eassumption.
  - specialize (IHeager_eval_expr1 E0 H2).
    specialize (IHeager_eval_expr2 E0 H2).
    inversion IHeager_eval_expr1. subst. inversion H4. subst.
    assert (match_env ge E1 E'). unfold match_env. intros. apply H7.
    inversion IHeager_eval_expr2. subst.
    assert (match_env ge (extend E1 id v0) (extend E' id av)). {
      unfold extend. unfold match_env. intros.
      destruct (ident_eq id0 id). econstructor. assumption.
      eapply H5.
    } idtac.
    eapply IHeager_eval_expr3 in H9.
    inversion H9. subst.
    repeat (econstructor; eauto).
  - specialize (IHeager_eval_expr1 E0 H2).
    specialize (IHeager_eval_expr2 E0 H2).
    inversion IHeager_eval_expr1. subst. inversion H4. subst.
    assert (match_env ge E1 E'). unfold match_env. intros. apply H7.
    inversion IHeager_eval_expr2. subst.
    assert (match_env ge (extend E1 id v0) (extend E' id (styp t))). {
      unfold extend. unfold match_env. intros.
      destruct (ident_eq id0 id). econstructor. assumption.
      eapply H5.
    } idtac.
    inversion H8. subst.
    eapply IHeager_eval_expr3 in H9.
    inversion H9. subst.
    repeat (econstructor; eauto).
  - eapply eager_to_strict_lazy_type in H; eauto.
    econstructor; eauto.
    econstructor; eauto. econstructor; eauto.
  - econstructor; eauto. econstructor; eauto.
  - admit. (* weird forall2 induction needed *)
Admitted.


Lemma list_of_strictval_of_strictlist :
  forall l,
    list_of_strictval (strict_list l) = Some l.
Proof.
  induction l; intros; simpl; auto.
  rewrite IHl. reflexivity.
Qed.

Lemma eager_eval_other_envs :
  forall ge Es vs exp,
    Forall2 (fun s => eager_eval_expr ge s exp) Es vs ->
    forall Es',
      Forall2 (fun E => fun E' => (forall v, eager_eval_expr ge E exp v <-> eager_eval_expr ge E' exp v)) Es Es' ->
      Forall2 (fun s => eager_eval_expr ge s exp) Es' vs.
Proof.
  induction 1; intros. inversion H. subst. econstructor.
  inversion H1. subst. econstructor; eauto.
  eapply H4; eauto.
Qed.        