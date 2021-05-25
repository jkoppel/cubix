

module Cubix.Rewriting.Rules.Rule (
    -- * Relations and Relata
    Relation

    -- * Rules
    -- ** Lenses
  , PartialBijection(..)
  , AssociativeLens(..)

    -- ** Rewrites
  , Rewrite
  , TermRewrite

    -- ** Rules
  , Premise
  , EPremise(..)
  , Rule

    -- ** Indices
  , RuleIndex(..)
  ) where

import Data.Map ( Map )
import Type.Reflection ( Typeable, TypeRep, typeRep )

import Data.Comp.Multi ( CxtS, TreeLike, E(..), (:-<:) )

import Cubix.Language.Parametric.InjF
import Cubix.Language.Parametric.Syntax

import           Cubix.Rewriting.Lenses.Associative ( AssociativeLens )
import qualified Cubix.Rewriting.Lenses.Associative as Associative
import           Cubix.Rewriting.Lenses.Bijective ( PartialBijection )
import qualified Cubix.Rewriting.Lenses.Bijective as Bijective

import Cubix.Rewriting.Rules.Matchable
import Cubix.Rewriting.Var

----------------------------------------------------------------------

-----------------------------------------------------------
------------------------ Relations ------------------------
-----------------------------------------------------------

data Relation a b = Relation { relation_longName  :: String
                             , relation_shortName :: String

                             , relation_leftType  :: TypeRep a
                             , relation_rightType :: TypeRep b
                             }

data ERelation where
  ERelation :: (Matchable a, Matchable b) => Relation a b -> ERelation


type TermRelation fs gs l1 l2 = Relation (RewritingTerm fs l1) (RewritingTerm gs l2)


-----------------------------------------------------------
-------------------------- Rules --------------------------
-----------------------------------------------------------


--------------------------
-------- Rewrites
--------------------------

data Rewrite a b = Rewrite a (Relation a b) b

type TermRewrite fs gs l1 l2 = Rewrite (RewritingTerm fs l1) (RewritingTerm gs l2)

--------------------------
-------- Rules
--------------------------

data AssociativePremiseBody b c where
  AssociativePremiseBody :: (Matchable b, Matchable c) =>  b -> [EPremise] -> c -> AssociativePremiseBody b c

data Premise a b where
  RewritePremise     :: Rewrite a b                    -> Premise a b
  LensPremise        :: a -> PartialBijection a b -> b -> Premise a b

  AssociativePremise :: a -> AssociativeLens b a -> AssociativePremiseBody b c -> AssociativeLens c d -> d -> Premise a d


data EPremise where
  EPremise :: (Matchable a, Matchable b) => Premise a b -> EPremise

-- Extra invariant: Rules are L-attributed. That is, all meta-variables
-- in the LHS of a premise must be in the LHS of a previous premise or of the conclusion
data Rule a b = (Rewrite a b) :- [EPremise]

infix 0 :-

type TermRewriteRule    fs gs l1 l2 = Rule (RewritingTerm fs l1) (RewritingTerm gs l2)
type TermIsoRewriteRule fs gs l     = TermRewriteRule fs gs l l

data ARule where
  ARule :: Rule a b -> ARule


--------------------------
-------- Indices
--------------------------

data RuleIndex = RuleIndex { lookupRulesRight :: forall a b. a -> Relation a b -> [Rule a b] -- Returns a list of rules that *might* match
                           , lookupRulesLeft  :: forall a b. Relation a b -> b -> [Rule a b] -- Returns a list of rules that *might* match
                           }


-------------------------------------------------------------
------------------- Desugaring relation ---------------------
-------------------------------------------------------------

desugar :: (Typeable fs, Typeable gs, Typeable l1, Typeable l2) => TermRelation fs gs l1 l2
desugar = Relation { relation_longName  = "desugars_to"
                   , relation_shortName = ":~>"
                   , relation_leftType  = typeRep
                   , relation_rightType = typeRep
                   }


(~>) :: (Typeable fs, Typeable gs, Typeable l1, Typeable l2)
     => RewritingTerm fs l1 -> RewritingTerm gs l2 -> TermRewrite fs gs l1 l2
(~>) a b = Rewrite a desugar b

infix 1 ~>

multidecRule1 :: ( MultiLocalVarDecl :-<: fs, SingleLocalVarDecl :-<: fs, SingleLocalVarDecl :-<: gs, ListF :-<: fs, ListF :-<: gs,
                   InjF fs MultiLocalVarDeclL l, InjF gs SingleLocalVarDeclL l,
                   Typeable fs, Typeable gs, Typeable l )
              => PartialBijection (RewritingTerm fs MultiLocalVarDeclCommonAttrsL, RewritingTerm fs LocalVarDeclAttrsL) (RewritingTerm gs LocalVarDeclAttrsL)
              -> TermRewriteRule fs gs l [l]
multidecRule1 joinAttrs = withVars5 ("attrs1", "attrs2", "binder", "init", "attrsJoined") $ \attrs1 attrs2 binder init attrsJoined ->
      iMultiLocalVarDecl attrs1 (SingletonF' (SingleLocalVarDecl' attrs2 binder init)) ~> SingletonF' (iSingleLocalVarDecl attrsJoined binder init)
      :-
      [ EPremise $ LensPremise (attrs1, attrs2) joinAttrs attrsJoined
      ]


multidecRule2 :: forall fs gs l.
                 ( MultiLocalVarDecl :-<: fs, SingleLocalVarDecl :-<: fs, SingleLocalVarDecl :-<: gs, ListF :-<: fs, ListF :-<: gs,
                   InjF fs MultiLocalVarDeclL l, InjF gs SingleLocalVarDeclL l,
                   Typeable fs, Typeable gs, Typeable l )
              => PartialBijection (RewritingTerm fs MultiLocalVarDeclCommonAttrsL, RewritingTerm fs LocalVarDeclAttrsL) (RewritingTerm gs LocalVarDeclAttrsL)
              -> TermRewriteRule fs gs l [l]
multidecRule2 joinAttrs =
  withVars5 ("attrs1", "attrs2", "binder", "init", "attrsJoined") $ \attrs1 attrs2 binder init attrsJoined ->
  withUniSigVars ("rest", "rest'") $ \(rest, rest') ->
      iMultiLocalVarDecl attrs1 (ConsF' (SingleLocalVarDecl' attrs2 binder init) rest) ~> ConsF' (iSingleLocalVarDecl attrsJoined binder init) rest'
      :-
      [ EPremise $ LensPremise (attrs1, attrs2) joinAttrs attrsJoined
      , EPremise $ RewritePremise $ (iMultiLocalVarDecl attrs1 rest :: RewritingTerm fs l) ~> rest'
      ]

blockRule :: forall fs gs l.
             ( Block :-<: fs, Block :-<: gs, TreeLike fs, TreeLike gs
             , ListF :-<: fs, ListF :-<: gs
             , ExtractF [] (RewritingTerm fs), ExtractF [] (RewritingTerm gs)
             , Typeable fs, Typeable gs )
          => TermIsoRewriteRule fs gs BlockL
blockRule =
   withVars3 ("body", "body'", "end") $ \body body' end ->
   withUniSigVars ("b", "bs") $ \(b, bs) ->
      iBlock body end ~> iBlock body' end
      :-
      [ EPremise $ AssociativePremise body
                                      (Associative.extractFLens @fs) -- Why can't it infer this from body?
                                      (AssociativePremiseBody b [EPremise $ RewritePremise (b ~> bs)] bs)
                                      (Associative.concatTermLens @gs)
                                      body'
      ]