Require Import List.
Import ListNotations.

Require Import Coqlib.


Lemma Forall_Forall2_implies :
  forall {A B} (P : A -> Prop) (Q R : A -> B -> Prop) (l : list A),
    Forall P l ->
    (forall a, P a -> forall b, Q a b -> R a b) ->
    forall (vs : list B),
      Forall2 Q l vs ->
      Forall2 R l vs.
Proof.
  induction 1; intros.
  inversion H0. subst.
  econstructor. 
  inversion H2. subst.
  econstructor; eauto.
Qed.

(* Just like Forall2, but with 3 lists *)
(* Good for modeling evaluation of binary operators *)
Inductive Forall3 {A B C : Type} (TR : A -> B -> C -> Prop) : list A -> list B -> list C -> Prop :=
| Forall3_nil :
    Forall3 TR [] [] []
| Forall3_cons :
    forall x y z lx ly lz,
      TR x y z ->
      Forall3 TR lx ly lz ->
      Forall3 TR (x :: lx) (y :: ly) (z :: lz).

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

Lemma firstn_map :
  forall {A B: Type} (f : A -> B)  n l,
    firstn n (map f l) = map f (firstn n l).
Proof.
  induction n; intros.
  simpl. reflexivity.
  simpl. destruct l; simpl. reflexivity.
  f_equal. eapply IHn.
Qed.

Lemma map_repeat_nil :
  forall {A B} k (f : A -> B),
    repeat [] k = map (map f) (repeat [] k).
Proof.
  induction k; intros; simpl; auto.
  f_equal. auto.
Qed.

Lemma length_list_drop :
  forall {A} (l : list A) n,
    (n > O)%nat ->
    l <> nil ->
    (Datatypes.length (list_drop n l) < Datatypes.length l)%nat.
Proof.
  induction l; intros.
  destruct n; simpl; try omega; congruence.
  simpl.
  destruct n; try omega.
  simpl.
  destruct n; try solve [simpl; auto].
  specialize (IHl (S n)).
  assert (l = nil \/ l <> []) by (destruct l; try solve [left; congruence]; right; congruence).
  destruct H1. subst l; simpl; auto.
  assert (S n > O)%nat by omega.
  eapply IHl in H2; try eapply H1. omega.
Qed.

Lemma map_injective_function :
  forall {A B} (f : A -> B) (l : list A),
    Forall (fun a => (forall b, f a = f b -> a = b)) l ->
    forall l',
      map f l = map f l' ->
      l = l'.
Proof.
  induction l; intros; simpl in *.
  destruct l'; simpl in *; try congruence; auto.
  destruct l'; simpl in *; try congruence.
  inversion H0.
  inversion H. subst. eapply H5 in H2. subst.
  f_equal.
  eapply IHl; eauto.
Qed.      

Lemma combine_injective :
  forall {A B : Type} (l1 : list A) (l2 : list B),
  forall l3 l4,
    combine l1 l2 = combine l3 l4 ->
    (Datatypes.length l1 = Datatypes.length l2) ->
    (Datatypes.length l3 = Datatypes.length l4) ->
    l1 = l3 /\ l2 = l4.
Proof.
  induction l1; intros; simpl in *.
  destruct l2; destruct l3; destruct l4; simpl in *; try congruence.
  split; auto.
  destruct l2; destruct l3; destruct l4; simpl in *; try congruence.
  inversion H0. inversion H1. inversion H. subst. clear H H0 H1.
  eapply IHl1 in H7; eauto. destruct H7. subst. split; auto.
Qed.

Lemma list_pair_parts_eq :
  forall {A B : Type} (l1 l2 : list (A * B)),
    map fst l1 = map fst l2 ->
    map snd l1 = map snd l2 ->
    l1 = l2.
Proof.
  induction l1; intros;
    destruct l2; simpl in *; try congruence.
  inversion H. inversion H0.
  f_equal.
  destruct a; destruct p; simpl in *.
  congruence.
  subst.
  eapply IHl1; eauto.
Qed.

Lemma firstn_app :
  forall {A} (l : list A) l',
    firstn (length l) (l ++ l') = l.
Proof.
  induction l; intros; simpl; auto.
  f_equal. eapply IHl.
Qed.

Lemma list_drop_app :
  forall {A} (l : list A) l',
    list_drop (length l) (l ++ l') = l'.
Proof.
  induction l; intros; simpl; auto.
Qed.

Lemma list_drop_length :
  forall {A} (l : list A) n,
    (length (list_drop n l) <= length l)%nat.
Proof.
  induction l; intros.
  simpl. destruct n; simpl; omega.
  simpl. destruct n; simpl. omega.
  specialize (IHl n). omega.
Qed.