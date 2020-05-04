{-# LANGUAGE ConstraintKinds        #-}
{-# LANGUAGE DataKinds              #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs                  #-}
{-# LANGUAGE MagicHash              #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE PolyKinds              #-}
{-# LANGUAGE RankNTypes             #-}
{-# LANGUAGE ScopedTypeVariables    #-}
{-# LANGUAGE TypeApplications       #-}
{-# LANGUAGE TypeFamilies           #-}
{-# LANGUAGE TypeOperators          #-}

module Data.Comp.Dict
       ( Dict (..)
       , All (..)
       , withDict
       , (\\)
       , dictFor
       ) where

import GHC.Exts
import Data.Vector (Vector)
import qualified Data.Vector as V
import qualified Unsafe.Coerce as U

import Data.Comp.Elem

-- NOTE: `E` exists in `Data.Comp.Multi.HFunctor` but it is not PolyKinded.
--       See dictFor function for a usage.
data E (f :: k1 -> *) where
  E :: f e -> E f

-- NOTE: ekmett's constraints also define a `Dict`
--       unfortunately it has a kind of `Constraint -> *`
data Dict (c :: k -> Constraint) (a :: k) where
  Dict :: c a => Dict c a

withDict :: Dict c a -> (c a => r) -> r
withDict Dict x = x

infixl 1 \\

(\\) :: (c a => r) -> Dict c a -> r
(\\) x Dict = x

class All (c :: k -> Constraint) (fs :: [k]) where
  dicts :: Proxy# fs -> Vector (E (Dict c))

instance All c '[] where
  {-# INLINE dicts #-}
  dicts _ = V.empty

instance (All c fs, c f) => All c (f ': fs) where
  {-# INLINE dicts #-}
  dicts p = E (Dict :: Dict c f) `V.cons` (dicts (reproxy @fs p))

reproxy :: forall b a. Proxy# a -> Proxy# b
reproxy _ = proxy#

{-# INLINE dictFor #-}
dictFor :: forall c f fs. (All c fs) => Elem f fs -> Dict c f
dictFor (Elem v) =
  let ds = dicts (proxy# :: Proxy# fs) :: Vector (E (Dict c))
  in case ds V.! v of
       E d -> U.unsafeCoerce d


