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
Require Import BuiltinSyntax.
Require Import BuiltinSem.

Open Scope list_scope.

(* Number of bits it takes to represent number n *)
Definition calc_width (n : Z) : Z :=
  if Z_eq_dec n 0 then 0 else
    1 + Z.log2 n.

Inductive eval_type (ge : genv) : env -> Typ -> Tval -> Prop :=
| eval_tvar_bound :
    forall E uid t k,
      E (uid,""%string) = Some (typ t) -> (* this lookup can be done with any string, as ident_eq only uses uid *)
      eval_type ge E (TVar (TVBound uid k)) t
(* | eval_tvar_free : *)
(* TODO: not sure what to do with free type variables...*)
| eval_trec :
    forall E l lv,
      Forall2 (eval_type ge E) (map snd l) (map snd lv) ->
      map fst l = map fst lv ->
      eval_type ge E (TRec l) (trec lv)
| eval_ttup :
    forall E l lv n,
      Forall2 (eval_type ge E) l lv ->
      n = length l ->
      eval_type ge E (TCon (TC (TCTuple n)) l) (ttup lv)
| eval_tseq :
    forall E l len lenv elem elemv,
      l = len :: elem :: nil ->
      eval_type ge E len lenv ->
      eval_type ge E elem elemv ->
      eval_type ge E (TCon (TC TCSeq) l) (tseq lenv elemv)
| eval_tnum :
    forall E n,
      eval_type ge E (TCon (TC (TCNum n)) nil) (tnum n)
| eval_tbit :
    forall E,
      eval_type ge E (TCon (TC TCBit) nil) tbit
| eval_tinf :
    forall E,
      eval_type ge E (TCon (TC TCInf) nil) tinf
| eval_tfunction_type_base :
    forall E a arg r res,
      eval_type ge E a arg ->
      eval_type ge E r res ->
      eval_type ge E (TCon (TC TCFun) (a :: r :: nil)) (tfun arg res)
| eval_tfunction_type_rec :
    forall E a r arg res,
      eval_type ge E a arg ->
      eval_type ge E (TCon (TC TCFun) r) res ->
      eval_type ge E (TCon (TC TCFun) (a :: r)) (tfun arg res)
| eval_type_add :
    forall E l r a b n,
      eval_type ge E l (tnum a) ->
      eval_type ge E r (tnum b) ->
      n = a + b ->
      eval_type ge E (TCon (TF TCAdd) (l :: r :: nil)) (tnum n)
| eval_type_sub :
    forall E l r a b n,
      eval_type ge E l (tnum a) ->
      eval_type ge E r (tnum b) ->
      n = a - b ->
      eval_type ge E (TCon (TF TCSub) (l :: r :: nil)) (tnum n)
| eval_type_mul :
    forall E l r a b n,
      eval_type ge E l (tnum a) ->
      eval_type ge E r (tnum b) ->
      n = a * b ->
      eval_type ge E (TCon (TF TCMul) (l :: r :: nil)) (tnum n)
| eval_type_div :
    forall E l r a b n,
      eval_type ge E l (tnum a) ->
      eval_type ge E r (tnum b) ->
      b <> 0 ->
      n = a / b ->
      eval_type ge E (TCon (TF TCDiv) (l :: r :: nil)) (tnum n)
| eval_type_mod :
    forall E l r a b n,
      eval_type ge E l (tnum a) ->
      eval_type ge E r (tnum b) ->
      b <> 0 ->
      n = a mod b ->
      eval_type ge E (TCon (TF TCMod) (l :: r :: nil)) (tnum n)
| eval_type_exp :
    forall E l r a b n,
      eval_type ge E l (tnum a) ->
      eval_type ge E r (tnum b) ->
      n = Z.pow a b ->
      eval_type ge E (TCon (TF TCExp) (l :: r :: nil)) (tnum n)
| eval_type_min :
    forall E l r a b n,
      eval_type ge E l (tnum a) ->
      eval_type ge E r (tnum b) ->
      n = Z.min a b ->
      eval_type ge E (TCon (TF TCMin) (l :: r :: nil)) (tnum n)
| eval_type_max :
    forall E l r a b n,
      eval_type ge E l (tnum a) ->
      eval_type ge E r (tnum b) ->
      n = Z.max a b ->
      eval_type ge E (TCon (TF TCMax) (l :: r :: nil)) (tnum n)
| eval_type_width :
    forall E e n,
      eval_type ge E e (tnum n) ->
      eval_type ge E (TCon (TF TCWidth) (e :: nil)) (tnum (calc_width n))
(* | eval_type_len_from_then_to : *)
(* | eval_type_len_from_then : *)
.



Inductive zero_val : Tval -> val -> Prop :=
| zero_bit :
    zero_val tbit (bit false)
| zero_tup :
    forall ts zvs,
      Forall2 zero_val ts zvs ->
      zero_val (ttup ts) (thunk_list zvs)
| zero_seq_fin :
    forall t v n vseq,
      zero_val t v ->
      vseq = thunk_list (repeat v (Z.to_nat n)) ->
      zero_val (tseq (tnum n) t) vseq
| zero_seq_inf :
    forall t v,
      (* TODO *)
      False ->
      zero_val (tseq tinf t) v
| zero_rec :
    forall lidtv vs vrec,
      Forall2 zero_val (map snd lidtv) vs ->
      vrec = rec (combine (map fst lidtv) vs) ->
      zero_val (trec lidtv) vrec
| zero_fun :
    forall argT resT v vfun,
      zero_val resT v ->
      vfun = close (0,"") (EValue v) empty ->
      zero_val (tfun argT resT) vfun
.

(* given the type of a zero, fill it in *)
(* Fixpoint zero_val (tv : Tval) : option val := *)
(*   match tv with *)
(*   | tbit => Some (bit false) *)
(*   | ttup ts => *)
(*     match collect (map zero_val ts) with *)
(*     | Some l => Some (tuple l) *)
(*     | _ => None *)
(*     end *)
(*   | tseq len t => *)
(*     match len with *)
(*     | tnum n => match zero_val t with *)
(*                 | Some v => Some (thunk_list (repeat v n)) *)
(*                 | None => None *)
(*                 end *)
(*     | tinf => None (* TODO *) *)
(*     | _ => None *)
(*     end *)
(*   | trec lidtv => None (* TODO *) *)
(*     (* match collect (map zero_val (map snd lidtv)) with *) *)
(*     (* | Some lv => Some (rec (combine (map fst lidtv) lv)) *) *)
(*     (* | None => None *) *)
(*     (* end *) *)
(*   | tfun argT resT => *)
(*     match zero_val resT with *)
(*     | Some v => Some (close (0,"") (EValue v) empty) *)
(*     | None => None *)
(*     end *)
(*   | tnum n => None (* Doesn't make sense as a type *) *)
(*   | tinf => None (* Doesn't make sense as a type *) *)
(*   end. *)


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


(* record lookup *)
Fixpoint lookup (str : string) (l : list (string * val)) : option val :=
  match l with
  | nil => None
  | (s,v) :: r =>
    if string_dec str s then Some v else lookup str r
  end.

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


Inductive eval_expr (ge : genv) : env -> Expr -> val -> Prop :=
| eval_builtin_sem :
    forall E l b v,
      eval_builtin ge E b l v ->
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
| eval_if :
    forall E c t f v b,
      eval_expr ge E c (bit b) ->
      eval_expr ge E (if b then t else f) v ->
      eval_expr ge E (EIf c t f) v
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
| eval_where : (* TODO: this might not get scoping right, as decls might not shadow existing locals correctly *)
    forall E exp decls v, 
      eval_expr (bind_decl_groups decls ge) E exp v ->
      eval_expr ge E (EWhere exp decls) v
| eval_list_sel :
    forall E idx vidx {w : nat} (i : BitV w) e v vs,
      eval_expr ge E idx vidx ->
      force_list ge E vidx vs ->
      to_bitv vs = Some i ->
      select_list ge E (Z.to_nat (unsigned i)) e v ->
      eval_expr ge E (ESel e (ListSel idx)) v
| eval_tapp :
    forall E e id e' E' v t te,
      eval_expr ge E e (tclose id e' E') ->
      eval_expr ge E te (typ t) -> 
      eval_expr ge (extend E' id (typ t)) e' v ->
      eval_expr ge E (ETApp e te) v
| eval_typ :
    forall E t tv,
      eval_type ge E t tv ->
      eval_expr ge E (ETyp t) (typ tv)
| eval_tabs :
    forall E e id,
      eval_expr ge E (ETAbs id e) (tclose id e E)
| eval_append_nil :
    forall E e1 e2 v,
      eval_expr ge E e1 vnil ->
      eval_expr ge E e2 v ->
      eval_expr ge E (EAppend e1 e2) v
| eval_append_cons :
    forall v eR ER E  vfirst vrest E' e1 e2,
      eval_expr ge E e1 (vcons v eR ER) ->
      eval_expr ge ER eR vfirst ->
      eval_expr ge E e2 vrest ->
      E' = extend (extend empty (1,"first") vfirst) (0,"rest") vrest ->
      eval_expr ge E (EAppend e1 e2) (vcons v (EAppend (EVar (1,"first")) (EVar (0,"rest"))) E')
| eval_head :
    forall E e v e' E',
      eval_expr ge E e (vcons v e' E') ->
      eval_expr ge E (EHead e) v
| eval_drop_zero :
    forall E e v,
      eval_expr ge E e v ->
      eval_expr ge E (EDrop O e) v
| eval_drop_succ :
    forall E e v e' E' n v',
      eval_expr ge E e (vcons v e' E') ->
      eval_expr ge E' (EDrop n e') v' ->
      eval_expr ge E (EDrop (S n) e) v'
| eval_take_zero :
    forall E e,
      eval_expr ge E (ETake O e) vnil
| eval_take_succ :
    forall e v e' E' E n,
      eval_expr ge E e (vcons v e' E') ->
      eval_expr ge E (ETake (S n) e) (vcons v (ETake n e') E')
| eval_value :
    forall E v,
      eval_expr ge E (EValue v) v

| eval_comp_imp_cons :
    forall E n llm E' e v vres,
      par_match ge E n llm E' ->
      eval_expr ge E' e v ->
      vres = vcons v (ECompImp e (S n) llm) E ->
      eval_expr ge E (ECompImp e n llm) vres
| eval_comp_imp_nil :
    forall E e llm n,
      totalmatchsize ge E llm n ->
      eval_expr ge E (ECompImp e n llm) vnil
| eval_comp :
    forall E e llm v,
      eval_expr ge E (ECompImp e O llm) v ->
      eval_expr ge E (EComp e llm) v
with totalmatchsize (ge : genv) : env -> list (list Match) -> nat -> Prop :=
     | size_one :
         forall E lm n,
           matchlength ge E lm n ->
           totalmatchsize ge E (lm :: nil) n
     | size_cons :
         forall E lm n lms,
           matchlength ge E lm n ->
           totalmatchsize ge E lms n ->
           totalmatchsize ge E (lm :: lms) n
(* Force complete evaluation of a lazy list *)
(* Used for converting a list of bits into a number to evaluate arithmetic *)
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
with matchlength (ge : genv) : env -> list Match -> nat -> Prop :=
     | len_one :
         forall E id e n l v,
           eval_expr ge E e v ->
           force_list ge E v l ->
           n = length l ->
           matchlength ge E ((From id e) :: nil) n
     | len_more :
         forall E id e r n l m v,
           matchlength ge E r n ->
           eval_expr ge E e v ->
           force_list ge E v m ->
           l = ((length m) * n)%nat ->
           matchlength ge E ((From id e) :: r) l
with force_list (ge : genv) : env -> val -> list val -> Prop :=
     | force_nil :
         forall E,
           force_list ge E vnil nil
     | force_cons :
         forall E E' e v v' l,
           eval_expr ge E' e v' ->
           force_list ge E v' l ->
           force_list ge E (vcons v e E') (v::l)
                
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
with eval_builtin (ge : genv) : env -> builtin -> list Expr -> val -> Prop :=
| eval_at :
    forall {w} E idx vidx vl l v t1 t2 t3 (bv : BitV w),
      eval_expr ge E idx vidx ->
      force_list ge E vidx vl ->
      to_bitv vl = Some bv ->
      select_list ge E (Z.to_nat (unsigned bv)) l v ->
      eval_builtin ge E At (t1 :: t2 :: t3 :: l :: idx :: nil) v
| eval_true :
    forall E,
      eval_builtin ge E true_builtin nil (bit true)
| eval_false :
    forall E,
      eval_builtin ge E false_builtin nil (bit false)
| eval_demote :
    forall E t1 value t2 width v,
      eval_expr ge E t1 (typ (tnum value)) ->
      eval_expr ge E t2 (typ (tnum width)) ->
      v = thunk_list (from_bitv (@repr (Z.to_nat width) value)) ->
      eval_builtin ge E Demote (t1 :: t2 :: nil) v
| eval_zero :
    forall E t tv zv,
      eval_expr ge E t (typ tv) ->
      zero_val tv zv ->
      eval_builtin ge E Zero (t :: nil) zv
| eval_split :
    forall args t1 t2 t3 le E n vfirst erest v,
      args = t1 :: t2 :: t3 :: le :: nil ->
      eval_expr ge E t1 (typ (tnum n)) ->
      eval_expr ge E (ETake (Z.to_nat n) le) vfirst ->
      erest = EBuiltin split (t1 :: t2 :: t3 :: (EDrop (Z.to_nat n) le) :: nil) ->
      v = vcons vfirst erest E ->
      eval_builtin ge E split args v
| eval_split_at :
    forall t1 t2 t3 l args E n vfirst vrest,
      args = t1 :: t2 :: t3 :: l :: nil ->
      eval_expr ge E t1 (typ (tnum n)) ->
      eval_expr ge E (ETake (Z.to_nat n) l) vfirst ->
      eval_expr ge E (EDrop (Z.to_nat n) l) vrest ->
      eval_builtin ge E splitAt args (tuple (vfirst :: vrest :: nil))
| eval_div_base : (* evaluate div over bitvectors *)
    (* different from other binary operators since can't divide by 0 *)
    forall {w} (b1 b2 : BitV w) E v1 v2 v3 l1 l2 t e1 e2,
      eval_expr ge E e1 v1 ->
      eval_expr ge E e2 v2 ->
      force_list ge E v1 l1 ->
      force_list ge E v2 l2 ->
      to_bitv l1 = Some b1 ->
      to_bitv l2 = Some b2 ->
      unsigned b2 <> 0 ->
      v3 = thunk_list (from_bitv (divu b1 b2)) ->
      eval_builtin ge E Div (t :: e1 :: e2 :: nil) (v3)

.



Inductive strict_eval_val (ge : genv) : val -> strictval -> Prop :=
| eval_sbit :
    forall b,
      strict_eval_val ge (bit b) (sbit b)
| eval_styp :
    forall t,
      strict_eval_val ge (typ t) (styp t)
| eval_srec :
    forall lide svals,
      Forall2 (strict_eval_val ge) (map snd lide) svals ->
      strict_eval_val ge (rec lide) (srec (combine (map fst lide) svals))
| eval_tup :
    forall lexp svals,
      Forall2 (strict_eval_val ge) lexp svals ->
      strict_eval_val ge (tuple lexp) (stuple svals)
| eval_nil :
    strict_eval_val ge vnil svnil
| eval_cons :
    forall E' e vrest r v f,
      eval_expr ge E' e vrest ->
      strict_eval_val ge vrest r ->
      strict_eval_val ge v f ->
      strict_eval_val ge (vcons v e E') (svcons f r)
| eval_close :
    forall id exp E SE,
      (forall id, option_rel (strict_eval_val ge) (E id) (SE id)) ->
      strict_eval_val ge (close id exp E) (sclose id exp SE)
| eval_tclose :
    forall id exp E SE,
      (forall id, option_rel (strict_eval_val ge) (E id) (SE id)) ->
      strict_eval_val ge (tclose id exp E) (stclose id exp SE)
.


Inductive strict_eval_expr (ge : genv) : env -> Expr -> strictval -> Prop :=
| eval_everything :
    forall E e v sv,
      eval_expr ge E e v ->
      strict_eval_val ge v sv ->
      strict_eval_expr ge E e sv.
    

(* | eval_eq_true : (* SUPER BIG HACK TODO TAKE OUT *) *)
(*     forall E e1 e2 v t, *)
(*       eval_expr ge E e1 v -> *)
(*       eval_expr ge E e2 v -> *)
(*       eval_builtin ge E Eq (t :: e1 :: e2 :: nil) (bit true) *)

(*
| eval_lift_unary_builtin :
    forall largs targs a E bi v,
      is_pointwise_liftable_unary bi -> 
      largs = targs ++ (a :: nil) ->
      eval_expr ge E (ELiftUnary bi targs a) v ->
      eval_builtin ge E bi largs v
| eval_lift_binary_builtin :
    forall largs targs a b E bi v,
      is_pointwise_liftable_binary bi -> 
      largs = targs ++ (a :: b :: nil) ->
      eval_expr ge E (ELiftBinary bi targs a b E E) v ->
      eval_builtin ge E bi largs v
(* lifting operations over lists lazily *)
| eval_lift_unary_cons :
    forall E a vinit e E' bi targs v,
      eval_expr ge E a (vcons vinit e E') ->
      eval_builtin ge E bi (targs ++ (EValue vinit) :: nil) v ->
      eval_expr ge E (ELiftUnary bi targs a) (vcons v (ELiftUnary bi targs e) E')
| eval_lift_unary_nil :
    forall E a vnil bi targs,
      eval_expr ge E a vnil ->
      eval_expr ge E (ELiftUnary bi targs a) vnil
| eval_lift_binary_cons :
    forall E a b AE BE v bi targs ae be aE' bE' va vb,
      eval_expr ge AE a (vcons va ae aE') ->
      eval_expr ge BE b (vcons vb be bE') ->
      eval_builtin ge E bi (targs ++ (EValue va) :: (EValue vb) :: nil) v ->
      eval_expr ge E (ELiftBinary bi targs a b AE BE) (vcons v (ELiftBinary bi targs ae be aE' bE') empty)
| eval_lift_binary_nil :
    forall E a b vnil bi targs AE BE,
      (* both lists must be same length to lift over, so no extra eval rule is needed if only one list is nil *)
      eval_expr ge AE a vnil ->
      eval_expr ge BE b vnil ->
      eval_expr ge E (ELiftBinary bi targs a b AE BE) vnil
(* lift operators over tuples *)
| eval_lift_unary_tuple :
    forall E e vs vs' bi targs,
      eval_expr ge E e (tuple vs) ->
      Forall2 (fun vx => eval_builtin ge E bi (targs ++ (EValue vx) :: nil)) vs vs' ->
      eval_expr ge E (ELiftUnary bi targs e) (tuple vs')
| eval_lift_binary_tuple :
    forall el er EL ER vsl vsr vs bi targs E,
      eval_expr ge EL el (tuple vsl) ->
      eval_expr ge ER er (tuple vsr) ->
      Forall3 (fun vl => fun vr => eval_builtin ge E bi (targs ++ (EValue vl) :: (EValue vr) :: nil)) vsl vsr vs ->
      eval_expr ge E (ELiftBinary bi targs el er EL ER) (tuple vs)
(* lift operators over records *)
| eval_lift_unary_record :
    forall E e lidv vs lidv' bi targs,
      eval_expr ge E e (rec lidv) ->
      Forall2 (fun vx => eval_builtin ge E bi (targs ++ (EValue vx) :: nil)) (map snd lidv) vs ->
      lidv' = combine (map fst lidv) vs ->
      eval_expr ge E (ELiftUnary bi targs e) (rec lidv')
| eval_lift_binary_record :
    forall el er EL ER lidvl lidvr vs lidv' bi targs E,
      eval_expr ge EL el (rec lidvl) ->
      eval_expr ge ER er (rec lidvr) ->
      Forall3 (fun vl => fun vr => eval_builtin ge E bi (targs ++ (EValue vl) :: (EValue vr) :: nil)) (map snd lidvl) (map snd lidvr) vs ->
      map fst lidvl = map fst lidvr ->
      lidv' = combine (map fst lidvl) vs ->
      eval_expr ge E (ELiftBinary bi targs el er EL ER) (rec lidv')
 *)



(* Below are 6 rules for lifting evaluation of builtins over records, tuples, and lists *)
(* The list rules look different because lists are lazy *)
(* | eval_lift_over_record_unary : *)
(*     forall bi largs targs r E lidv vl v, *)
(*       is_pointwise_liftable_unary bi -> *)
(*       largs = targs ++ (r :: nil) -> *)
(*       eval_expr ge E r (rec lidv) -> *)
(*       Forall2 (fun a => fun v => eval_builtin ge E bi (targs ++ a :: nil) v) *)
(*               (map EValue (map snd lidv)) vl -> *)
(*       v = rec (combine (map fst lidv) vl) -> *)
(*       eval_builtin ge E bi largs v *)
(* | eval_lift_over_record_binary : *)
(*     forall bi largs targs r1 r2 E lidv1 lidv2 vl v, *)
(*       is_pointwise_liftable_binary bi -> *)
(*       largs = targs ++ (r1 :: r2 :: nil) -> *)
(*       eval_expr ge E r1 (rec lidv1) -> *)
(*       eval_expr ge E r2 (rec lidv2) -> *)
(*       Forall3 (fun a1 => fun a2 => fun v => eval_builtin ge E bi (targs ++ a1 :: a2 :: nil) v) *)
(*               (map EValue (map snd lidv1)) *)
(*               (map EValue (map snd lidv2)) vl -> *)
(*       map fst lidv1 = map fst lidv2 -> *)
(*       v = rec (combine (map fst lidv1) vl) -> *)
(*       eval_builtin ge E bi largs v *)
(* | eval_lift_over_tuple_unary : *)
(*     forall bi largs targs E l lv vl v, *)
(*       is_pointwise_liftable_unary bi -> *)
(*       largs = targs ++ (l :: nil) -> *)
(*       eval_expr ge E l (tuple lv) -> *)
(*       Forall2 (fun a => fun v => eval_builtin ge E bi (targs ++ a :: nil) v) (map EValue lv) vl -> *)
(*       v = tuple vl -> *)
(*       eval_builtin ge E bi largs v *)
(* | eval_lift_over_tuple_binary : *)
(*     forall E bi largs v vl targs l1 l2 lv1 lv2, *)
(*       is_pointwise_liftable_binary bi -> *)
(*       largs = targs ++ (l1 :: l2 :: nil) -> *)
(*       eval_expr ge E l1 (tuple lv1) -> *)
(*       eval_expr ge E l2 (tuple lv2) -> *)
(*       Forall3 (fun a1 => fun a2 => fun v => eval_builtin ge E bi (targs ++ a1 :: a2 :: nil) v) (map EValue lv1) (map EValue lv2) vl -> *)
(*       v = tuple vl ->               *)
(*       eval_builtin ge E bi largs v *)
(* | eval_lift_over_list_unary : *)
(*     forall bi largs targs l E lv vs vl v, *)
(*       is_pointwise_liftable_unary bi -> *)
(*       largs = targs ++ (l :: nil) -> *)
(*       eval_expr ge E l lv -> *)
(*       force_list ge E lv vs -> *)
(*       Forall2 (fun a => fun v => eval_builtin ge E bi (targs ++ a :: nil) v) (map EValue vs) vl -> *)
(*       v = thunk_list vl -> *)
(*       eval_builtin ge E bi largs v *)
(* | eval_lift_over_list_binary : *)
(*     forall E l1 vs1 l2 vs2 v targs largs bi lv1 lv2 vl, *)
(*       is_pointwise_liftable_binary bi -> *)
(*       largs = targs ++ (l1 :: l2 :: nil) -> (* last 2 are the values, could be arbitrary # of type args *) *)
(*       eval_expr ge E l1 lv1 -> *)
(*       eval_expr ge E l2 lv2 -> *)
(*       force_list ge E lv1 vs1 -> *)
(*       force_list ge E lv2 vs2 -> *)
(*       Forall3 (fun a1 => fun a2 => fun v => eval_builtin ge E bi (targs ++ a1 :: a2 :: nil) v) (map EValue vs1) (map EValue vs2) vl -> *)
(*       v = thunk_list vl -> *)
(*       eval_builtin ge E bi largs v *)
(* | eval_minus : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @sub w b1 b2 -> *)
(*       eval_builtin ge Minus (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_times : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @mul w b1 b2 -> *)
(*       eval_builtin ge Times (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_div : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @divu w b1 b2 -> (* I assume that division is unsigned in cryptol *) *)
(*       unsigned b2 <> 0 -> (* no division by 0 *) *)
(*       eval_builtin ge Div (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_mod : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @modu w b1 b2 -> *)
(*       eval_builtin ge Mod (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* (* | eval_exp : *) (* TODO: write pow over bits, or implement in Cryptol *) *)
(* (*     forall {w : nat} {nz : w <> O} (b1 b2 b3 : BitV w) t, *) *)
(* (*       b3 = @exp w nz b1 b2 -> *) *)
(* (*       eval_builtin ge Exp (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *) *)
(* (* | eval_lg2 : *) (* TODO: what is lg2? log base 2? *) *)
(* (*     forall {w : nat} {nz : w <> O} (b1 b2 b3 : BitV w) t, *) *)
(* (*       b3 = @lg2 w nz b1 b2 -> *) *)
(* (*       eval_builtin ge lg2 (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *) *)
(* | eval_negate : *)
(*     forall {w : nat} (b1 b2 : BitV w) t, *)
(*       b2 = @neg w b1 -> *)
(*       eval_builtin ge Neg (t :: (bits b1) :: nil) (bits b2) *)
(* | eval_compl : *)
(*     forall {w : nat} (b1 b2 : BitV w) t, *)
(*       b2 = @not w b1 -> *)
(*       eval_builtin ge Compl (t :: (bits b1) :: nil) (bits b2) *)
(* | eval_lt : *)
(*     forall {w : nat} (b1 b2 : BitV w) (b : bool) t, *)
(*       b = @ltu w b1 b2 -> *)
(*       eval_builtin ge Lt (t :: (bits b1) :: (bits b2) :: nil) (bit b) *)
(* | eval_gt : *)
(*     forall {w : nat} (b1 b2 : BitV w) (b : bool) t, *)
(*       b = @gtu w b1 b2 -> *)
(*       eval_builtin ge Gt (t :: (bits b1) :: (bits b2) :: nil) (bit b) *)
(* | eval_le :   *)
(*     forall {w : nat} (b1 b2 : BitV w) (b : bool) t, *)
(*       b = @leu w b1 b2 -> *)
(*       eval_builtin ge Le (t :: (bits b1) :: (bits b2) :: nil) (bit b) *)
(* | eval_ge : *)
(*     forall {w : nat} (b1 b2 : BitV w) (b : bool) t, *)
(*       b = @geu w b1 b2 -> *)
(*       eval_builtin ge Ge (t :: (bits b1) :: (bits b2) :: nil) (bit b) *)
(* | eval_eq : *)
(*     forall {w : nat} (b1 b2 : BitV w) (b : bool) t, *)
(*       b = @eq w b1 b2 -> *)
(*       eval_builtin ge Eq (t :: (bits b1) :: (bits b2) :: nil) (bit b) *)
(* | eval_neq : *)
(*     forall {w : nat} (b1 b2 : BitV w) (b : bool) t, *)
(*       b = @neq w b1 b2 -> *)
(*       eval_builtin ge Neq (t :: (bits b1) :: (bits b2) :: nil) (bit b) *)
(* | eval_and : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @and w b1 b2 -> *)
(*       eval_builtin ge And (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_or : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @or w b1 b2 -> *)
(*       eval_builtin ge Or (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_xor : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @xor w b1 b2 -> *)
(*       eval_builtin ge Xor (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_zero : (* TODO: cryptol's builtin zero works in more cases than this *) *)
(*     forall {ws : nat} (w : Z) (b : BitV ws), *)
(*       ws = Z.to_nat w -> *)
(*       b = @repr ws 0 ->  *)
(*       eval_builtin ge Zero ((typ (TCon (TC (TCNum w)) nil)) :: nil) (bits b) *)
(* | eval_shiftl : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @shl w b1 b2 -> *)
(*       eval_builtin ge Shiftl (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_shiftr : *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @shru w b1 b2 -> *)
(*       eval_builtin ge Shiftr (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_rotl :     *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @rol w b1 b2 -> *)
(*       eval_builtin ge Rotl (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* | eval_rotr :     *)
(*     forall {w : nat} (b1 b2 b3 : BitV w) t, *)
(*       b3 = @ror w b1 b2 -> *)
(*       eval_builtin ge Rotr (t :: (bits b1) :: (bits b2) :: nil) (bits b3) *)
(* (*                    *)
(* | eval_append : *)
(*     forall E t1 t2 t3 v1 v2 e1 e2, *)
(*       e1 = EVar (1,"") -> *)
(*       e2 = EVar (2,"") -> *)
(*       E = extend (extend empty (1,"") v1) (2,"") v2  -> *)
(*       eval_expr ge E (EAppend e1 e2) v -> *)
(*       eval_builtin ge Append (t1 :: t2 :: t3 :: v1 :: v2 :: nil) v *) *)
(* | eval_at_bits : *)
(*     forall {w : nat} E n e v t1 t2 t3 v1 (b : BitV w), *)
(*       select_list ge E n e v -> *)
(*       E = extend empty (0,"") v1 -> *)
(*       e = EVar (0,"") -> *)
(*       n = Z.to_nat (unsigned b) -> *)
(*       eval_builtin ge At (t1 :: t2 :: t3 :: v1 :: (bits b) :: nil) v *)
(*| eval_splitAt :
    forall E e v front back t,
      E = extend empty (1,"") v ->
      e = EVar (1,"") ->
      eval_builtin ge splitAt ((typ (TCon (TC (TCNum front)) nil)) :: (typ (TCon (TC (TCNum back)) nil)) :: t :: v :: nil)
                   (tuple ((vslice O (Z.to_nat front) e E) :: (vslice (Z.to_nat front) (Z.to_nat (front + back)) e E) :: nil))
| eval_split :
    forall E e v n m t,
      E = extend empty (1,"") v ->
      e = EVar (1,"") ->
      eval_builtin ge split ((typ (TCon (TC (TCNum n)) nil)) :: (typ (TCon (TC (TCNum m)) nil)) :: t :: v :: nil)
                   (vsplit n m e E)*)
(*| eval_join : *)
(* Produces the one dimensional cartesian product of a 2 dimensional sequence *)
(* sorta like a list comprehension *)
(*
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
*)
(*     | select_comp :
         forall E e compExp compE llm n E' v,
           eval_expr ge E e (vcomp compExp compE llm) ->
           par_match ge compE n llm E' ->
           eval_expr ge E' compExp v ->
           select_list ge E n e v
     | select_app_1 :
         forall E e e1 e2 AE n v,
           eval_expr ge E e (vapp  e1 e2 AE) ->
           select_list ge AE n e1 v ->
           select_list ge E n e v
     | select_app_2 :
         forall E e e1 e2 AE n v m k,
           eval_expr ge E e (vapp e1 e2 AE) ->
           length ge AE e1 m ->
           select_list ge AE k e2 v ->
           n = (m + k)%nat ->
           select_list ge E n e v
     | select_slice :
         forall E e lo hi lexp AE n k v,
           eval_expr ge E e (vslice lo hi lexp AE) ->
           k = (lo + n)%nat ->
           select_list ge AE k lexp v ->
           select_list ge E n e v
     | select_split : (* yields a slice, gets selected again *)
         forall E e k j lexp AE lo hi n,
           eval_expr ge E e (vsplit k j lexp AE) ->
           lo = (n * (Z.to_nat j))%nat ->
           hi = (lo + (Z.to_nat j))%nat ->
           select_list ge E n e (vslice lo hi lexp AE)
| eval_binary_over_bitv_to_bitv :
    forall {w} bi E el vl er vr ll lr (bl : BitV w) br vres targ args
           (pr : strict_total_binary_op_over_bitv_to_bitv bi),
      args = targ :: el :: er :: nil -> (* TODO: will there ever be more than one targ? *)
      eval_expr ge E el vl ->
      eval_expr ge E er vr ->
      force_list ge E vl ll ->
      force_list ge E vr lr ->
      to_bitv ll = Some bl ->
      to_bitv lr = Some br ->
      vres = thunk_list (from_bitv ((binop_sem_bitv_to_bitv bi) pr bl br)) ->
      eval_builtin ge E bi args vres
| eval_binary_over_bitv_to_bit :
    forall {w} bi E el vl er vr ll lr (bl : BitV w) br vres targ args 
           (pr : strict_total_binary_op_over_bitv_to_bit bi),
      args = targ :: el :: er :: nil -> (* TODO: will there ever be more than one targ? *)
      eval_expr ge E el vl ->
      eval_expr ge E er vr ->
      force_list ge E vl ll ->
      force_list ge E vr lr ->
      to_bitv ll = Some bl ->
      to_bitv lr = Some br ->
      vres = bit ((binop_sem_bitv_to_bit bi) pr bl br) ->
      eval_builtin ge E bi args vres
| eval_binary_over_bit_to_bit :
    forall bi targ args E el er vl vr (pr : binary_op_over_bit_to_bit bi),
      args = targ :: el :: er :: nil ->
      eval_expr ge E el (bit vl) ->
      eval_expr ge E er (bit vr) ->
      eval_builtin ge E bi args (bit (binop_sem_bit_to_bit bi pr vl vr))
*)
    



