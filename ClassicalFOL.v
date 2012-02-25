Require Import List.
Require Import Classical.

(* a convenient representation for interpreting sequents; this is how we'll receive inputs
   from the external system. *)
Inductive deduction :=
  | dd : list Prop -> list Prop -> deduction.

Notation "P |= Q" := (dd P Q) (at level 90).
Notation "[ x ; .. ; y ]" := (cons x .. (cons y nil) ..).

Definition denote (s : deduction) : Prop :=
  match s with
    | dd hyp con => fold_right and True hyp -> fold_right or False con
  end.

Lemma contrapositive : forall (A B : Prop), (~ B -> ~ A) <-> (A -> B).
  intros; destruct (classic B); tauto.
Qed.

(* Slightly opaque definition to help us keep track of hypotheses
versus parametric values and temporary hypotheses *)
Definition Hyp (x : Prop) := x.
Definition Con (x : Prop) := x. (* not used by anyone, here to make the numbering start from 0 *)

Ltac wrap H := let T := type of H in change (Hyp T) in H.

Ltac explode myfresh H tac :=
  repeat (let h := myfresh idtac in tac; destruct H as [ h H ]; wrap h); clear H.
Ltac conjExplode H := explode ltac:(fun _ => fresh "Hyp") H ltac:idtac.
Ltac negDisjExplode H := explode ltac:(fun _ => fresh "Con") H ltac:(apply not_or_and in H).

Ltac sequent := simpl; let H := fresh in intro H; conjExplode H.

(* Heavy machinery for handling right-side rules *)

Ltac rollup H tac :=
  repeat match goal with
           | [ H' : Hyp _ |- _ ] => revert H' end;
  repeat match goal with
           | [ |- _ -> _ ] =>
             let h := fresh in intro h;
             let ht := type of h in
             let Ht := type of H in
             let g := fresh in
             assert (ht /\ Ht) as g; [constructor; assumption |];
             (* messy *)
             clear H; clear h; rename g into H; tac
         end;
  unfold Hyp in H;
  revert H.

Ltac posneg :=
  let H := fresh in
  assert True as H by trivial;
  rollup H ltac:idtac;
  apply -> contrapositive;
  intro H;
  negDisjExplode H.

Ltac negpos :=
  let H := fresh in
  assert (~ False) as H by tauto;
  rollup H ltac:(apply and_not_or in H);
  apply <- contrapositive;
  intro H;
  conjExplode H.

Ltac canonicalize := posneg; negpos; posneg; negpos. (* twice, to prevent the ordering from reversing *)

(* Heavy machinery that will be used to implement right-side rules *)

Ltac negImp H :=
  match type of H with Hyp (~ (_ (* H1 *) -> _ (* H2 *))) =>
    unfold Hyp in H; apply imply_to_and in H;
    (* H : H1 /\ ~ H2 *)
    let H1 := fresh in
    let H2 := fresh in
    destruct H as [H1 H2];
    (* Want to move H1 to the bottom (since it is positive); keep H2 up top *)
    match goal with
      [ |- ?G ] =>
        let h := fresh in
        let T1 := type of H1 in
        assert (h : ~ T1 \/ G); [|
          let nH1 := fresh in let G' := fresh in
          destruct h as [ nH1 | G' ]; [ contradict H1; exact nH1 | exact G' ]
        ]
    end;
    clear H1;
    wrap H2;
    apply not_and_or
  end.

Ltac negDisj H :=
  match type of H with Hyp (~ (_ (* H1 *) \/ _ (* H2 *))) =>
    unfold Hyp in H; apply not_or_and in H;
    (* H : ~ H1 /\ ~ H2 *)
    let H1 := fresh in
    let H2 := fresh in
    destruct H as [ H1 H2 ];
    wrap H1; wrap H2
  end.

(* actual user visible tactics *)

Ltac myExact H :=
  solve [unfold Hyp in H; repeat match goal with [ |- ?P \/ ?Q ] => try (solve [left; exact H]); right end].
Ltac myCut := fail.

(* alternatively, duplicate the hypothesis and only provide fst and snd projection *)
Ltac lConj H :=
  match type of H with Hyp (_ /\ _) =>
    let h1 := fresh in let h2 := fresh in unfold Hyp in H; destruct H as [h1 h2];
    let t1 := type of h1 in let t2 := type of h2 in change (Hyp t1) in h1; change (Hyp t2) in h2
  end; canonicalize.
Ltac lDisj H := fail.
Ltac lImp H := fail.
(*
  match type of H with Hyp (?P -> ?Q) =>
    match goal with [ |- ?G ] =>
      assert P; *)
Ltac lBot H := fail.
Ltac lForall H t := fail.
Ltac lExists H := fail.
Ltac lDup H := fail.

Ltac rWrap tac H := posneg; tac H; negpos; posneg; negpos.

Ltac rConj H := fail.
(* Alternatively, commit to a disjunction *)
Ltac rDisj H := rWrap negDisj H.
Ltac rImp H := rWrap negImp H.
Ltac rForall H := fail.
Ltac rExists H t := fail.
Ltac rDup H := fail.

Section universe.

Parameter U : Set.
Variable z : U. (* non-empty domain *)
Variables A B C : Prop. (* some convenient things to instantiate with *)

(* an example *)
Goal denote ( [ True; C /\ C ] |= [ False; False; False; ((A -> B) -> A) -> A ] ).
  sequent.
    lConj Hyp1.
    rImp Con3.
Abort.

Goal denote ( nil |= [ ((A -> B) -> A) -> A ] ).
  sequent.
    rImp Con0.

Goal denote ( nil |= [ A \/ (A -> False) ] ).
  sequent.
    rDisj Con0.
    rImp Con1.
    myExact Hyp0.
Qed.

End Section.