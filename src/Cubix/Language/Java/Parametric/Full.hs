{-# OPTIONS_HADDOCK hide #-}
{-# LANGUAGE CPP #-}
#ifdef ONLY_ONE_LANGUAGE
module Cubix.Language.Java.Parametric.Full () where
#else

-- A parametric syntax for Java which perfectly follows the original
-- 
-- Most of this file has been autogenerated from the non-parametric syntax in
-- 'Language.Java.Syntax' using the @comptrans@ library.

module Cubix.Language.Java.Parametric.Full
  (
    module Cubix.Language.Java.Parametric.Full.Types
  , module Cubix.Language.Java.Parametric.Full.Trans
  ) where

import Cubix.Language.Java.Parametric.Full.Types
import Cubix.Language.Java.Parametric.Full.Trans

#endif