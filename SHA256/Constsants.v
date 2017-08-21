Require Import List.
Import ListNotations.

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

Require Import Prims.
Require Import SHA256.
Require Import HexConvert.

Import HaskellListNotations.
Require Import String.
Open Scope string.


Definition K_spec : ext_val :=
  let l :=
      [ "0x428a2f98", "0x71374491", "0xb5c0fbcf", "0xe9b5dba5", "0x3956c25b", "0x59f111f1", "0x923f82a4", "0xab1c5ed5",
      "0xd807aa98", "0x12835b01", "0x243185be", "0x550c7dc3", "0x72be5d74", "0x80deb1fe", "0x9bdc06a7", "0xc19bf174",
      "0xe49b69c1", "0xefbe4786", "0x0fc19dc6", "0x240ca1cc", "0x2de92c6f", "0x4a7484aa", "0x5cb0a9dc", "0x76f988da",
      "0x983e5152", "0xa831c66d", "0xb00327c8", "0xbf597fc7", "0xc6e00bf3", "0xd5a79147", "0x06ca6351", "0x14292967",
      "0x27b70a85", "0x2e1b2138", "0x4d2c6dfc", "0x53380d13", "0x650a7354", "0x766a0abb", "0x81c2c92e", "0x92722c85",
      "0xa2bfe8a1", "0xa81a664b", "0xc24b8b70", "0xc76c51a3", "0xd192e819", "0xd6990624", "0xf40e3585", "0x106aa070",
      "0x19a4c116", "0x1e376c08", "0x2748774c", "0x34b0bcb5", "0x391c0cb3", "0x4ed8aa4a", "0x5b9cca4f", "0x682e6ff3",
      "0x748f82ee", "0x78a5636f", "0x84c87814", "0x8cc70208", "0x90befffa", "0xa4506ceb", "0xbef9a3f7", "0xc67178f2"
     ]
  in
  eseq (map (fun x => eseq (val_of_hex_lit x)) l).

Lemma K_eval :
  forall GE TE SE,
    wf_env ge GE TE SE ->
    forall res,
      res = to_sval K_spec ->
      eager_eval_expr GE TE SE (EVar K) res.
Proof.
  intros.
  gen_global K.
  gen_global (0,"demote").
  ag.
  clear H1.
  e; try use demote_eval.
  subst res.
  unfold K_spec.
  unfold val_of_hex_lit. simpl.
  reflexivity.
Qed.

Lemma K_type :
  has_type K_spec (tseq 64 (tseq 32 tbit)).
Proof.
  unfold K_spec.
  simpl. unfold val_of_hex_lit. simpl.
  repeat (econstructor; eauto).
Qed.
