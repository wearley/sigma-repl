{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}

module Model
( Expr(..)
, Expr'(..)
, bruijns
) where

import Module
import Data.Maybe
import qualified Data.Map.Strict as Map

type Expr = Expr' ID
data Expr' a = Stop
             | Perm [Expr' a] [Expr' a]
             | Seq [Expr' a]
             | Label a
             | As a (Expr' a)
             | Ref a deriving (Eq, Ord)

----

instance Aliasable Expr where
    type Sig Expr = Expr' [Int]
    type Ref Expr = String

    sig = sig' Map.empty

    slots Stop = []
    slots (Label _) = []
    slots (Perm l r) = slots' l ++ slots' r
    slots (Seq xs) = slots' xs
    slots (As l x) = slots x
    slots (Ref r) = [r]

slots' = concat . map slots

sig' :: Ord a => Map.Map a [Int] -> Expr' a -> Expr' [Int]
sig' _ Stop = Stop
sig' _ (Perm l r) = Perm (map (sig' m) l) (map (sig' m) r)
  where m = bruijns [2] (Seq r) $ bruijns [1] (Seq l) Map.empty
sig' m (Seq x) = Seq $ map (sig' m) x
sig' m (Label l) = Label . fromMaybe [] $ Map.lookup l m
sig' m (As l x) = As (fromMaybe [] $ Map.lookup l m) (sig' m x)
sig' _ (Ref _) = Ref []

bruijns :: Ord a => [Int] -> Expr' a -> Map.Map a [Int] -> Map.Map a [Int]
bruijns _ Stop m = m
bruijns _ (Perm _ _) m = m
bruijns pre (Seq xs) m = foldl (\m' (n, x) -> bruijns (n:pre) x m') m $ zip [1..] xs
bruijns pre (Label l) m = Map.alter f l m
  where
    f Nothing = Just pre
    f x@(Just _) = x
    --f Nothing = Just [pre]
    --f (Just x) = Just (pre:x)
bruijns pre (As l x) m = bruijns pre x $ bruijns pre (Label l) m
bruijns _ (Ref _) m = m
--bruijns pre (Ref r) m = bruijns pre (Label r) m
