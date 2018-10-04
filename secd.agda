module secd where

open import Data.Fin using (Fin; zero; suc)
open import Data.List using (List; []; [_]; _∷_; length; lookup)
open import Data.Integer using (ℤ; +_)


-- Type of atomic constants. These can be loaded directly from a single instruction.
data Const : Set where
  true false : Const
  int : ℤ → Const

mutual
  -- Environment stores the types of bound variables.
  Env = List Type

  -- Types that our machine recognizes.
  data Type : Set where
    intT boolT : Type
    pairT : Type → Type → Type
    funT : Type → Type → Type
    envT : Env → Type
    listT : Type → Type

-- Closure is a function together with a context.
closureT : Type → Type → Env → Type
closureT a b env = pairT (funT a b) (envT env)

-- Assignment of types to constants.
typeof : Const → Type
typeof true    = boolT
typeof false   = boolT
typeof (int x) = intT

-- Stack stores the types of values on the machine's stack.
Stack = List Type

-- Special kind of closure we use to allow recursive calls.
data Closure : Set where
  mkClosure : Type → Type → Env → Closure

-- Boilerplate.
mkFrom : Closure → Type
mkFrom (mkClosure from _ _) = from
mkTo : Closure → Type
mkTo (mkClosure _ to _) = to
mkEnv : Closure → Env
mkEnv (mkClosure _ _ env) = env

-- This is pretty much the call stack, allowing us to make recursive calls.
FunDump = List Closure

-- A state of our machine.
record State : Set where
  constructor _#_#_
  field
    s : Stack
    e : Env
    f : FunDump

-- The typing relation.
infix 5 ⊢_↝_
infixr 5 _>>_
data ⊢_↝_ : State → State → Set where
  -- Composition of instructions.
  _>>_ : ∀ {s₁ s₂ s₃ e₁ e₂ e₃ f₁ f₂ f₃}
       → ⊢ s₁ # e₁ # f₁ ↝ s₂ # e₂ # f₂
       → ⊢ s₂ # e₂ # f₂ ↝ s₃ # e₃ # f₃
       → ⊢ s₁ # e₁ # f₁ ↝ s₃ # e₃ # f₃
  ldf  : ∀ {s e f from to}
       → (⊢ [] # (from ∷ e) # (mkClosure from to e ∷ f) ↝ [ to ] # [] # f)
       → ⊢ s # e # f ↝ (closureT from to e ∷ s) # e # f
  lett : ∀ {s e f x}
       → ⊢ (x ∷ s) # e # f ↝ s # (x ∷ e) # f
  ap   : ∀ {s e e' f from to}
       → ⊢ (from ∷ closureT from to e' ∷ s) # e # f ↝ (to ∷ s) # e # f
  tc   : ∀ {s e f}
       → (at : Fin (length f))
       → let cl = lookup f at in
         ⊢ (mkFrom cl ∷ s) # e # f ↝ (mkTo cl ∷ s) # e # f
  rtn  : ∀ {s e e' a b f x}
       → ⊢ (b ∷ s) # e # (mkClosure a b e' ∷ f) ↝ [ x ] # [] # f
  nil  : ∀ {s e f a}
       → ⊢ s # e # f ↝ (listT a ∷ s) # e # f
  ldc  : ∀ {s e f}
       → (const : Const)
       → ⊢ s # e # f ↝ (typeof const ∷ s) # e # f
  ld   : ∀ {s e f}
       → (at : Fin (length e))
       → ⊢ s # e # f ↝ (lookup e at ∷ s) # e # f
  flip : ∀ {s e f a b}
       → ⊢ (a ∷ b ∷ s) # e # f ↝ (b ∷ a ∷ s) # e # f
  cons : ∀ {s e f a}
       → ⊢ (a ∷ listT a ∷ s) # e # f ↝ (listT a ∷ s) # e # f
  head : ∀ {s e f a}
       → ⊢ (listT a ∷ s) # e # f ↝ (a ∷ s) # e # f
  tail : ∀ {s e f a}
       → ⊢ (listT a ∷ s) # e # f ↝ (listT a ∷ s) # e # f
  pair : ∀ {s e f a b}
       → ⊢ (a ∷ b ∷ s) # e # f ↝ (pairT a b ∷ s) # e # f
  fst  : ∀ {s e f a b}
       → ⊢ (pairT a b ∷ s) # e # f ↝ (a ∷ s) # e # f
  snd  : ∀ {s e f a b}
       → ⊢ (pairT a b ∷ s) # e # f ↝ (b ∷ s) # e # f
  add  : ∀ {s e f}
       → ⊢ (intT ∷ intT ∷ s) # e # f ↝ (intT ∷ s) # e # f
  nil? : ∀ {s e f a}
       → ⊢ (listT a ∷ s) # e # f ↝ (boolT ∷ s) # e # f
  not  : ∀ {s e f}
       → ⊢ (boolT ∷ s) # e # f ↝ (boolT ∷ s) # e # f
  if   : ∀ {s s' e e' f f' x}
       → ⊢ s # e # f ↝ s' # e' # f'
       → ⊢ s # e # f ↝ s' # e' # f'
       → ⊢ (x ∷ s) # e # f ↝ s' # e' # f'


-- 2 + 3
_ : ⊢ [] # [] # [] ↝ [ intT ] # [] # []
_ =
    ldc (int (+ 2))
 >> ldc (int (+ 3))
 >> add

-- λx.x + 1
inc : ⊢ [] # (intT ∷ []) # (mkClosure intT intT [] ∷ []) ↝
        ((intT ∷ []) # [] # []) -- ∀ {s e f} → ⊢ s # e # f ↝ (closureT intT intT e ∷ s) # e # f
inc =
    ld zero
 >> ldc (int (+ 1))
 >> add
 >> rtn

-- Apply 2 to the above.
_ : ⊢ [] # [] # [] ↝ [ intT ] # _ # []
_ =
    ldf inc
 >> ldc (int (+ 2))
 >> ap

-- Partial application test.
_ : ⊢ [] # [] # [] ↝ [ intT ] # [] # []
_ =
     ldf -- First, we construct the curried function.
       (ldf
         (ld zero >> ld (suc zero) >> add >> rtn) >> rtn)
  >> ldc (int (+ 1)) -- Load first argument.
  >> ap              -- Apply to curried function. Results in a closure.
  >> ldc (int (+ 2)) -- Load second argument.
  >> ap              -- Apply to closure.

-- Shit getting real.
foldl : ∀ {a b e f} → ⊢ [] # [] # _ ↝
          [ closureT                          -- We construct a function,
              (closureT b (closureT a b e) e) -- which takes the folding function,
              (closureT b                     -- returning a function which takes acc,
                (closureT (listT a)           -- returning a function which takes the list,
                  b                           -- and returns the acc.
                  (b ∷ [ closureT b (closureT a b e) e ])) [ closureT b (closureT a b e) e ]) [] ] # _ # f
foldl = ldf (ldf (ldf body >> rtn) >> rtn)
  where
    body =
         ld zero                   -- Load list.
      >> nil?                      -- Is it empty?
      >> if (ld (suc zero) >> rtn) -- If so, load & return acc.
          (ld (suc (suc zero))     -- If not, load folding function.
        >> ld (suc zero)           -- Load previous acc.
        >> ap                      -- Partially apply folding function.
        >> ld zero                 -- Load list.
        >> head                    -- Get the first element.
        >> ap                      -- Apply, yielding new acc.
        >> ld (suc (suc zero))     -- Load the folding function.
        >> tc (suc (suc zero))     -- Partially-tail apply the folding function to us.
        >> flip                    -- Flip resulting closure with our new acc.
        >> ap                      -- Apply acc, result in another closure.
        >> ld zero                 -- Load list.
        >> tail                    -- Drop the first element we just processed.
        >> ap                      -- Finally apply the last argument, that rest of the list.
        >> rtn)                    -- Once that returns, just return the result.
