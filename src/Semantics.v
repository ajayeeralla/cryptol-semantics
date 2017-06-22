Require Import List.
Import ListNotations.
Require Import Coq.Arith.PeanoNat.
Require Import String.

(* Borrow from CompCert *)
Require Import Coqlib.

Require Import Integers.
Require Import AST.
Require Import Builtins.
Require Import Values.
Require Import BuiltinSem.

Definition extend { vtype : Type } (E : ident -> option vtype) (id : ident) (v : vtype) :=
  fun x => if ident_eq x id then Some v else E x.

Definition genv := ident -> option Expr.
Definition gempty : genv := fun _ => None.

Fixpoint declare (l : list Declaration) (ge : genv) :=
  match l with
  | nil => ge
  | (Decl id (DExpr e)) :: r =>
    declare r (extend ge id e)
  | (Decl id DPrim) :: r =>
    match lookup_prim id with
    | Some exp =>
      declare r (extend ge id exp)
    | None => declare r ge (* TODO: maybe handle this as an error? *)
    end
  end.

Definition bind_decl_group (g : DeclGroup) (ge : genv) : genv :=
  match g with
  | Recursive l => declare l ge
  | NonRecursive d => declare (d :: nil) ge
  end.

Fixpoint bind_decl_groups (lg : list DeclGroup) (ge : genv) : genv :=
  match lg with
  | nil => ge
  | g :: gs =>
    bind_decl_groups gs (bind_decl_group g ge)
  end.


Definition env := ident -> option val.
Definition empty : env := fun _ => None.



(* Conversion from fully computed finite list to lazy list via trivial thunking *)
Fixpoint thunk_list (l : list val) : val :=
  match l with
  | nil => vnil
  | f :: r =>
    vcons f (EVar (0,""%string)) (extend empty (0,""%string) (thunk_list r))
  end.


(* TODO: is this used? *)
Lemma nat_nz :
  forall z (nz : z > 0),
    Z.to_nat z <> O.
Proof.
  intros.
  unfold Z.gt in *. unfold Z.compare in *. 
  destruct z; simpl in nz; try congruence.
  unfold Z.to_nat.
  remember (Pos2Nat.is_pos p). omega.
Qed.  

(* record lookup *)
Fixpoint lookup (str : string) (l : list (string * val)) : option val :=
  match l with
  | nil => None
  | (s,v) :: r =>
    if string_dec str s then Some v else lookup str r
  end.

Inductive eval_expr (ge : genv) : env -> Expr -> val -> Prop :=
| eval_builtin_sem :
    forall E l vs b v,
      Forall2 (eval_expr ge E) l vs ->
      eval_builtin b vs v ->
      eval_expr ge E (EBuiltin b l) v
| eval_list :
    forall E l vs vres,
      Forall2 (eval_expr ge E) l vs ->
      vres = thunk_list vs ->
      eval_expr ge E (EList l) vres
| eval_tuple :
    forall E l vs,
      Forall2 (eval_expr ge E) l vs ->
      eval_expr ge E (ETuple l) (tuple vs)
| eval_tuple_sel :
    forall E e l n v,
      eval_expr ge E e (tuple l) ->
      nth_error l n = Some v ->
      eval_expr ge E (ESel e (TupleSel n)) v
| eval_record :
    forall E l vs,
      Forall2 (eval_expr ge E) (map snd l) vs ->
      eval_expr ge E (ERec l) (rec (combine (map fst l) vs))
| eval_record_sel :
    forall E l str v e,
      eval_expr ge E e (rec l) ->
      lookup str l = Some v ->
      eval_expr ge E (ESel e (RecordSel str)) v
(* TODO: eval_list_sel *)                
| eval_if_t : 
    forall E c t f v,
      eval_expr ge E c (bit true) ->
      eval_expr ge E t v ->
      eval_expr ge E (EIf c t f) v
| eval_if_f :
    forall E c t f v,
      eval_expr ge E c (bit false) ->
      eval_expr ge E f v ->
      eval_expr ge E (EIf c t f) v
| eval_comp :
    forall E e l,
      eval_expr ge E (EComp e l) (vcomp e E l)
| eval_local_var :
    forall E id v,
      E id = Some v ->
      eval_expr ge E (EVar id) v
| eval_global_var :
    forall E id v exp,
      E id = None ->
      ge id = Some exp ->
      eval_expr ge E exp v ->
      eval_expr ge E (EVar id) v
| eval_abs :
    forall E id exp,
      eval_expr ge E (EAbs id exp) (close id exp E)
| eval_app :
    forall E f id exp E' a av v,
      eval_expr ge E f (close id exp E') ->
      eval_expr ge E a av ->
      eval_expr ge (extend E' id av) exp v ->
      eval_expr ge E (EApp f a) v
| eval_where :
    forall E exp decls v,
      eval_expr (bind_decl_groups decls ge) E exp v ->
      eval_expr ge E (EWhere exp decls) v
| eval_list_sel :
    forall E idx {w : nat} (i : BitV w) v e,
      eval_expr ge E idx (bits i) ->
      select_list ge E (Z.to_nat (unsigned i)) e v ->
      eval_expr ge E (ESel e (ListSel idx)) v

| eval_tapp :
    forall E e id e' E' v t,
      eval_expr ge E e (tclose id e' E') ->
      eval_expr ge (extend E' id (typ t)) e' v ->
      eval_expr ge E (ETApp e t) v
| eval_tabs :
    forall E e id,
      eval_expr ge E (ETAbs id e) (tclose id e E)


(* select the nth element from a lazy list *)
with select_list (ge : genv) : env -> nat -> Expr -> val -> Prop :=
     | select_zero :
         forall E e v re rE,
           eval_expr ge E e (vcons v re rE) ->
           select_list ge E O e v
     | select_succ :
         forall E e v re rE n v',
           eval_expr ge E e (vcons v' re rE) ->
           select_list ge rE n re v ->
           select_list ge E (S n) e v
     | select_comp :
         forall E e compExp compE llm n E' v,
           eval_expr ge E e (vcomp compExp compE llm) ->
           par_match ge compE n llm E' ->
           eval_expr ge E' compExp v ->
           select_list ge E n e v
with par_match (ge : genv) : env -> nat -> list (list Match) -> env -> Prop :=
     | par_one :
         forall E n,
           par_match ge E n nil E
     | par_more :
         forall E n lm E' lr E'',
           index_match ge E n lm E' ->
           par_match ge E' n lr E'' ->
           par_match ge E n (lm :: lr) E''
(* provide the nth bound environment for one part of a list comprehension *)
with index_match (ge : genv) : env -> nat -> list Match -> env -> Prop :=
     | idx_last : (* take the nth element from the last list *)
         forall E n id e v,
           select_list ge E n e v ->
           index_match ge E n ((From id e) :: nil) (extend E id v)
     | idx_mid : (* take the mid element from *)
         forall E E' n r v id e m t len,
           index_match ge E n r E' ->
           select_list ge E (S m) e v ->
           matchlength ge E r len ->
           (* m * matchlength r  + n *)
           t = (((S m) * len) + n)%nat ->
           index_match ge E t ((From id e) :: r) (extend E' id v)
     | idx_first :
         forall E n r E' v id e,
           index_match ge E n r E' ->
           select_list ge E O e v ->
           index_match ge E n ((From id e) :: r) (extend E' id v)

(* because the lists are potentially infinite, we can't  *)
with matchlength (ge : genv) : env -> list Match -> nat -> Prop :=
     | len_one :
         forall E id e n,
           length ge E e n ->
           matchlength ge E ((From id e) :: nil) n
     | len_more :
         forall E id e r n l m,
           matchlength ge E r n ->
           length ge E e m ->
           l = (m * n)%nat ->
           matchlength ge E ((From id e) :: r) l
with length (ge : genv) : env -> Expr -> nat -> Prop :=
     | len_nil :
         forall E e,
           eval_expr ge E e vnil ->
           length ge E e O
     | len_cons :
         forall E e v rE re n,
           eval_expr ge E e (vcons v re rE) ->
           length ge rE re n ->
           length ge E e (S n)
.




(* List comprehension is weird *)

(* | eval_comp : (* Doesn't yet tie the knot, no self reference yet *) *)
(*     forall l head vs E lvs' lvs, *)
(*       Forall2 (eval_expr ge E) (map snd l) lvs' -> *)
(*       lvs' = map seq lvs -> *)
(*       Forall2 (fun e' v => eval_expr ge e' head v) (comp_envs E (combine (map fst l) lvs)) vs -> *)
(*       eval_expr ge E (EComp head l) (seq vs) *)

(*| eval_list_sel_fin :
    forall {n} E lst lv idx (bs : BitV n) v,
      eval_expr E lst (seq lv) ->
      eval_expr E idx (bits bs) ->
      nth_error lv (nat_of_bits bs) = Some v ->
      eval_expr E (EListSel lst idx) v
| eval_list_sel_inf :
    forall {n} E lst g E' idx (bs : BitV n) v,
      eval_expr E lst (infseq g E') ->
      eval_expr E idx (bits bs) ->
      eval_expr E' (g (nat_of_bits bs)) v ->
      eval_expr E (EListSel lst idx) v*)

(* Definition extend_list (E : env) (id : ident) (vs : list val) : list env := *)
(*   map (fun x => extend E id x) vs. *)

(* Fixpoint decl_exprs (l : list Declaration) : list Expr := *)
(*   match l with *)
(*   | nil => nil *)
(*   | (Decl id (DExpr e)) :: r => e :: decl_exprs r *)
(*   end. *)

(* Fixpoint decl_ids (l : list Declaration) : list ident := *)
(*   match l with *)
(*   | nil => nil *)
(*   | (Decl id _) :: r => id :: decl_ids r *)
(*   end. *)
(* Definition zrepr {w : Z} {nz : w > 0} (n : Z) : BitV (Z.to_nat w). *)
(*   refine (@repr (Z.to_nat w) _ n). *)
(*   unfold Z.gt in *. unfold Z.compare in *. *)
(*   destruct w; simpl in nz; try congruence. *)
(*   unfold Z.to_nat. *)
(*   remember (Pos2Nat.is_pos p). omega. *)
(* Defined. *)

(* Fixpoint fold_extend (E : env) (l : list (ident * val)) : env := *)
(*   match l with *)
(*   | nil => E *)
(*   | (id,v) :: r => extend (fold_extend E r) id v *)
(*   end. *)



(* Special case of a numeric program literal, e is always EVar 0 so that might be some builtin we could define *)
(* | eval_tapp_const : *)
(*     forall E e n (w : Z) (nz : w > 0) wn (nz' : wn <> O), *)
(*       wn = Z.to_nat w -> *)
(*       eval_expr ge E (ETApp (ETApp e (TCon (TC (TCNum n)) nil)) (TCon (TC (TCNum w)) nil)) (bits (@repr wn nz' n)) *)
