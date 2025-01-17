#!/usr/bin/env stack
{- stack
  --resolver lts-12.11
  --install-ghc runghc
  --package aeson
  --package aeson-pretty
  --package bytestring
  --package text
-}

-- This script simply outputs the JSON used to configure Karabiner-Elements
-- Tou must redirect the output it into the appropriate file, e.g.
--    ~/dotfiles/.config/karabiner/assets/complex_modifications/linux.json
-- There is a wrapper script that handles this for us
--    ~/dotfiles/.config/karabiner/update

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wall -Werror #-}
-- Don't fail to compile due to unused local binds
{-# OPTIONS_GHC -Wno-error=unused-local-binds #-}

import Prelude hiding (mod)
import Data.Aeson
import Data.Aeson.Types
import Data.Aeson.Encode.Pretty hiding (Tab)
import qualified Data.ByteString.Lazy.Char8 as LC
import Data.Functor ((<&>))
import Data.Maybe
import Data.String
import Data.Text (Text)
import qualified Data.Text as T
import qualified GHC.TypeLits as TL
import GHC.TypeLits (ErrorMessage((:$$:)))

main :: IO ()
main =  LC.putStrLn $ pretty root

root :: Root
root = Root "Linux Compat" [rule]
  where
  rule = Rule "Various remappings to make it feel like linux" $ mempty
    <> generalRemaps
    <> terminalRemaps
    <> intellijRemaps
    <> slackRemaps
    <> notTerminalOrIntelliJRemaps
    <> skhdRemaps
    <> chunkwmRemaps
    -- <> vimArrowsRemaps
    -- <> moveWindowToWorkspaceRemaps
    -- <> switchWorkspaceRemaps

  generalRemaps =
    [ -- Spotlight
      Command |+| P !> RightCommand |+| Spacebar
    ]

  terminalRemaps = concat
    [
      -- Tmux: Switch windows with Ctrl+<number>
      numbers >>= \n -> [ Option |+| n !> tmuxPrefix |-> singleKey n ]
    , [
        -- Tmux: Next window
        Option |+| N !> tmuxPrefix |-> singleKey N
        -- Tmux: Previous window
      , Option |+| P !> tmuxPrefix |-> singleKey P
        -- Copy
      , [Control, Shift] |+| C !> RightCommand |+| C
        -- Paste
      , [Control, Shift] |+| V !> RightCommand |+| V
      ]

      -- Tmux: Use option+hjkl for moving between panes
    -- , [H, J, K, L] <&> \hjkl ->
    --     Option |+| hjkl !> tmuxPrefix |-> singleKey hjkl
    ] ?? [macterm, iterm]

  -- The Option + Key mappings in IntelliJ don't work consistently due
  -- to Mac's preference to insert unicode chars instead.
  -- These mappings override that behavior.
  intellijRemaps = concat
    [ [ -- Jump to Super method
        Option |+| U !> RightCommand |+| U
        -- Preferences
      , [Control, Option] |+| S !> RightCommand |+| Comma
        -- Project Structure
      , [Shift, Control, Option] |+| S !> RightCommand |+| Semicolon
      ]

      -- Tmux-ish: Use option+hjkl for moving between panes
      -- This works because I already have some bindings in IntelliJ for
      -- tmuxPrefix + hjkl
    , [H, J, K, L] <&> \hjkl ->
        Option |+| hjkl !> tmuxPrefix |-> singleKey hjkl
    ] ?? [intellij]

  slackRemaps =
    (numbers >>= \n -> [ Control |+| n !> RightCommand |+| n ])
    ?? [slack]

  -- These bindings don't work well with iterm2 or intellij due
  -- to clashes with vim, tmux, etc, so excluding them with ??!
  notTerminalOrIntelliJRemaps =
    (
      -- Useful for moving to tab n of an app, e.g. browser.
      (map (\n -> Option |+| n !> RightCommand |+| n) numbers)
      <>
      [ -- New tab
        Control |+| T !> RightCommand |+| T
        -- Open closed tab
      , [Control, Shift] |+| T !> [RightCommand, RightShift] |+| T
        -- Close tab
      , Control |+| W !> RightCommand |+| W
        -- Copy
      , Control |+| C !> RightCommand |+| C
        -- Cut
      , Control |+| X !> RightCommand |+| X
        -- Paste
      , Control |+| V !> RightCommand |+| V
        -- Paste without formatting
      , [Control, Shift] |+| V !> [RightCommand, RightShift] |+| V
        -- Select all
      , Control |+| A !> RightCommand |+| A
        -- Find
      , Control |+| F !> RightCommand |+| F
        -- Reload
      , Control |+| R !> RightCommand |+| R
        -- Force reload
      , [Shift, Control] |+| R !> [RightShift, RightCommand] |+| R
        -- Undo
      , Control |+| Z !> RightCommand |+| Z
        -- Redo
      , Control |+| Y !> RightCommand |+| Y
        -- Highlight address
      , Control |+| L !> RightCommand |+| L
        -- Previous tab
      , [Option, Shift] |+| OpenBracket  !> [RightCommand, RightShift] |+| OpenBracket
        -- Next tab
      , [Option, Shift] |+| CloseBracket !> [RightCommand, RightShift] |+| CloseBracket
        -- Back / Forward
      , Option |+| LeftArrow  !> RightCommand |+| LeftArrow
      , Option |+| RightArrow !> RightCommand |+| RightArrow
        -- Delete previous word
      , Control |+| Backspace !> RightOption |+| Backspace
        -- Chrome: Private tab
      , [Control, Shift] |+| N !> [RightCommand, RightShift] |+| N
        -- Firefox: Private tab
      , [Control, Shift] |+| P !> [RightCommand, RightShift] |+| P
        -- Slack: Go to conversation
      , Control |+| K !> RightCommand |+| K
      , Control |+| ReturnOrEnter !> RightCommand |+| ReturnOrEnter
        -- Print
      , Control |+| P !> RightCommand |+| P
      ]
    ) ??! [macterm, iterm, intellij]

  skhdRemaps = [One, Two, Three, Four, Five] >>= \n ->
    [ -- Mapped in ~/.skhdrc
      Command |+| n !> chunkMod |+| n
    ]

  -- Key maps to use simulate Xmonad.
  chunkwmRemaps =
    [
      -- Focus monitor 1
      Command |+| W !> chunkMod |+| W
      -- Focus monitor 2
    , Command |+| E !> chunkMod |+| E
      -- Focus monitor 3
    , Command |+| R !> chunkMod |+| R
      -- Move window to monitor 1
    , [Shift, Command] |+| W !> chunkShiftMod |+| W
      -- Move window to monitor 2
    , [Shift, Command] |+| E !> chunkShiftMod |+| E
      -- Move window to monitor 3
    , [Shift, Command] |+| R !> chunkShiftMod |+| R
      -- Focus previous window
    , Command |+| J !> chunkMod |+| J
      -- Focus next window
    , Command |+| K !> chunkMod |+| K
      -- Move window to previous
    , [Shift, Command] |+| J !> chunkShiftMod |+| J
      -- Move window to next
    , [Shift, Command] |+| K !> chunkShiftMod |+| K
      -- Default (bsp) layout
    , Command |+| Spacebar !> chunkMod |+| Spacebar
      -- Full (monocle) layout
    , [Shift, Command] |+| Spacebar !> chunkShiftMod |+| Spacebar
      -- Toggle float current window
    , Command |+| T !> chunkMod |+| T
      -- Grow region
    , Command |+| H !> chunkMod |+| H
      -- Shrink region
    , Command |+| L !> chunkMod |+| L
    ]

  -- switchWorkspaceRemaps = numbers >>= \n ->
  --   [ -- Use Command+number instead of Control+number for switching workspaces.
  --     Command          |+| n !> RightControl  |+| n
  --   ]

  -- moveWindowToWorkspaceRemaps = numbers >>= \n ->
  --   [ -- Use Shift+Command+number to move window to workspace via chunkwm
  --     [Shift, Command] |+| n !> chunkShiftMod |+| n
  --   ]

  -- vimArrowsRemaps =
  --   [ -- Remap Option+h/j/k/l to arrow keys
  --     Option |+| H !> LeftArrow
  --   , Option |+| J !> DownArrow
  --   , Option |+| K !> UpArrow
  --   , Option |+| L !> RightArrow
  --     -- Remap Shift+Option+h/j/k/l to shift+arrow keys
  --     -- Useful when highlighting with vim arrows
  --   , [Shift, Option] |+| H !> RightShift |+| LeftArrow
  --   , [Shift, Option] |+| J !> RightShift |+| DownArrow
  --   , [Shift, Option] |+| K !> RightShift |+| UpArrow
  --   , [Shift, Option] |+| L !> RightShift |+| RightArrow
  --   ]

  -- My ~/.chunkwmrc uses these keys as "mod" keys
  chunkMod = [RightControl, RightOption, RightCommand]
  chunkShiftMod = RightShift : chunkMod

  tmuxPrefix = RightControl |+| A

  -- Number keys on the keyboard, useful for generating key maps via loops.
  numbers = [One, Two, Three, Four, Five, Six, Seven, Eight, Nine, Zero]

  -- Patterns for binding keys only for certain apps.
  iterm = litPat "com.googlecode.iterm2"
  macterm = litPat "com.apple.Terminal"
  -- chrome = litPat "com.google.Chrome"
  intellij = litPat "com.jetbrains.intellij"
  slack = litPat "com.tinyspeck.slackmacgap"

-----------------------------------

-- Converts a text literal to an application regex pattern.
litPat :: Text -> Text
litPat t = '^' `T.cons` (T.replace "." "\\." t) `T.snoc` '$'

data KeyBinding a = KeyBinding [a] KeyCode

-- | Key binding with no modifiers.
singleKey :: KeyCode -> KeyBinding PhysicalModifier
singleKey = KeyBinding []

-- | Helper for a key binding sequence, only slightly prettier than using a list.
-- Later we can refactor this if we need to chain more than two; that will probably
-- require a type class.
(|->) :: KeyBinding a -> KeyBinding a -> [KeyBinding a]
x |-> y = [x, y]

infix 5 |->

class ToKeyBinding a b c | a b -> c where
  (|+|) :: a -> b -> KeyBinding c
  infix 6 |+|

instance ToKeyBinding PhysicalModifier KeyCode PhysicalModifier where
  mod |+| kc = KeyBinding [mod] kc

instance ToKeyBinding [PhysicalModifier] KeyCode PhysicalModifier where
  mods |+| kc = KeyBinding mods kc

instance ToKeyBinding MetaModifier KeyCode MetaModifier where
  mod |+| kc = KeyBinding [mod] kc

instance ToKeyBinding [MetaModifier] KeyCode MetaModifier where
  mods |+| kc = KeyBinding mods kc

-- | Maps first KeyBinding to second KeyBinding
-- We can map physical modifiers to physical modifiers or meta modifiers
-- to physical modifiers, but we can't (or rather, shouldn't) map
-- any modifiers to meta modifiers; these type class instances enforce this.
-- We provide an instance for this via TypeError to provide nice error
-- messages.
class ManipulatorBuilder a b where
  (!>) :: a -> b -> Manipulator
  infix 4 !>

instance AsAnyModifier a
  => ManipulatorBuilder (KeyBinding a) (KeyBinding PhysicalModifier) where
  (KeyBinding fromMods fromK) !> (KeyBinding toMods toK) =
    Manipulator Basic mf [mt] Nothing
    where
    mf = ManipulatorFrom fromK (FromModifiers $ map asAnyModifier fromMods)
    mt = ManipulatorTo   toK   toMods

instance AsAnyModifier a
  => ManipulatorBuilder (KeyBinding a) [KeyBinding PhysicalModifier] where
  (KeyBinding fromMods fromK) !> toBindingSeq =
    Manipulator Basic mf mts Nothing
    where
    mf = ManipulatorFrom fromK (FromModifiers $ map asAnyModifier fromMods)
    mts = flip map toBindingSeq $ \(KeyBinding toMods toK) ->
            ManipulatorTo toK toMods

instance AsAnyModifier a
  => ManipulatorBuilder (KeyBinding a) KeyCode where
  fromKeys !> toKey = fromKeys !> ([] :: [PhysicalModifier]) |+| toKey

instance
  TL.TypeError
    (     'TL.Text "Unsupported ManipulatorBuilder (!>) usage;"
    ':$$: 'TL.Text "'to' binding must use a PhysicalModifier (e.g. RightControl)"
    ':$$: 'TL.Text "not a MetaModifier (e.g. Control)"
    )
  => ManipulatorBuilder a (KeyBinding MetaModifier) where
  (!>) = undefined

-- | Adds 'frontmost_application_if' condition to Manipulator
(?) :: Manipulator -> [Text] -> Manipulator
m ? ts = m { manipulatorConditions = cs }
  where
  c = ManipulatorCondition FrontmostApplicationIf ts
  cs = Just $ c : fromMaybe [] (manipulatorConditions m)

-- | Same as ? except updates a list of Manipulator
(??) :: [Manipulator] -> [Text] -> [Manipulator]
ms ?? ts = map (? ts) ms

-- | Adds 'frontmost_application_unless' condition to Manipulator
(?!) :: Manipulator -> [Text] -> Manipulator
m ?! ts = m { manipulatorConditions = cs }
  where
  c = ManipulatorCondition FrontmostApplicationUnless ts
  cs = Just $ c : fromMaybe [] (manipulatorConditions m)

infix 3 ?!

-- | Same as ?! except updates a list of Manipulator
(??!) :: [Manipulator] -> [Text] -> [Manipulator]
ms ??! ts = map (?! ts) ms

pretty :: Root -> LC.ByteString
pretty = encodePretty' prettyConfig

prettyConfig :: Config
prettyConfig = defConfig
  { confIndent = Spaces 2
  , confCompare = prettyConfigCompare
  }

prettyConfigCompare :: Text -> Text -> Ordering
prettyConfigCompare = keyOrder
  [ "title"
  , "rules"
  , "description"
  , "manipulators"
  , "type"
  , "from"
  , "to"
  , "conditions"
  , "key_code"
  , "modifiers"
  ]

stripNulls :: [Pair] -> [Pair]
stripNulls xs = filter (\(_,v) -> v /= Null) xs

data Root = Root
  { rootTitle :: Text
  , rootRules :: [Rule]
  }

instance ToJSON Root where
  toJSON (Root title rules) =
    object ["title" .= title, "rules" .= rules]

data Rule = Rule
  { ruleDescription :: Text
  , ruleManipulators :: [Manipulator]
  }

instance ToJSON Rule where
  toJSON (Rule d ms) =
    object ["description" .= d, "manipulators" .= ms]

data Manipulator = Manipulator
  { manipulatorType :: ManipulatorType
  , manipulatorFrom :: ManipulatorFrom
  , manipulatorTo :: [ManipulatorTo]
  , manipulatorConditions :: Maybe [ManipulatorCondition]
  }

instance ToJSON Manipulator where
  toJSON (Manipulator typ from to conds) = object $ stripNulls
    [ "type" .= typ
    , "from" .= from
    , "to" .= to
    , "conditions" .= conds
    ]

data ManipulatorType = Basic

manipulatorTypeToText :: ManipulatorType -> Text
manipulatorTypeToText = \case
  Basic -> "basic"

instance ToJSON ManipulatorType where
  toJSON = toJSON . manipulatorTypeToText

data ManipulatorFrom = ManipulatorFrom
  { fromKeyCode :: KeyCode
  , fromModifiers :: FromModifiers
  }

instance ToJSON ManipulatorFrom where
  toJSON (ManipulatorFrom k ms) =
    object ["key_code" .= k, "modifiers" .= ms]

data ManipulatorTo = ManipulatorTo
  { toKeyCode :: KeyCode
  , toModifiers :: [PhysicalModifier]
  }

instance ToJSON ManipulatorTo where
  toJSON (ManipulatorTo k ms) =
    object ["key_code" .= k, "modifiers" .= ms]

data ManipulatorCondition = ManipulatorCondition
  { conditionType :: ManipulatorConditionType
  , conditionBundleIdentifiers :: [Text]
  }

instance ToJSON ManipulatorCondition where
  toJSON (ManipulatorCondition t bis) =
    object ["type" .= t, "bundle_identifiers" .= bis]

data ManipulatorConditionType
  = FrontmostApplicationUnless
  | FrontmostApplicationIf

manipulatorConditionTypeToText :: ManipulatorConditionType -> Text
manipulatorConditionTypeToText = \case
  FrontmostApplicationUnless -> "frontmost_application_unless"
  FrontmostApplicationIf -> "frontmost_application_if"

instance ToJSON ManipulatorConditionType where
  toJSON = toJSON . manipulatorConditionTypeToText

data FromModifiers = FromModifiers
  { modifiersMandatory :: [AnyModifier]
  }

instance ToJSON FromModifiers where
  toJSON (FromModifiers m) =
    object ["mandatory" .= m]

data PhysicalModifier
  = LeftShift | RightShift
  | LeftControl | RightControl
  | LeftOption | RightOption
  | LeftCommand | RightCommand

instance ToJSON PhysicalModifier where
  toJSON = \case
    LeftShift -> "left_shift"
    RightShift -> "right_shift"
    LeftControl -> "left_control"
    RightControl -> "right_control"
    LeftOption -> "left_option"
    RightOption -> "right_option"
    LeftCommand -> "left_command"
    RightCommand -> "right_command"

data MetaModifier
  = Shift
  | Control
  | Option
  | Command

instance ToJSON MetaModifier where
  toJSON = \case
    Shift -> "shift"
    Control -> "control"
    Option -> "option"
    Command -> "command"

data AnyModifier
  = ModifierFromPhysical PhysicalModifier
  | ModifierFromMeta MetaModifier

class AsAnyModifier a where
  asAnyModifier :: a -> AnyModifier

instance AsAnyModifier PhysicalModifier where
  asAnyModifier = ModifierFromPhysical

instance AsAnyModifier MetaModifier where
  asAnyModifier = ModifierFromMeta

instance ToJSON AnyModifier where
  toJSON mf = case mf of
    ModifierFromPhysical m -> toJSON m
    ModifierFromMeta m -> toJSON m

-- | Key codes available for binding
-- The full list can be viewed in the Karabiner-Elements source
-- https://github.com/tekezo/Karabiner-Elements/blob/master/src/share/types.hpp
data KeyCode
  = A | B | C | D | E | F | G | H | I | J | K | L | M
  | N | O | P | Q | R | S | T | U | V | W | X | Y | Z
  | One | Two | Three | Four | Five | Six | Seven | Eight | Nine | Zero
  | Spacebar | Backspace
  | OpenBracket | CloseBracket
  | RightArrow | LeftArrow | UpArrow | DownArrow
  | ReturnOrEnter
  | Tab
  | Comma | Semicolon

keyCodeToString :: IsString a => KeyCode -> a
keyCodeToString = \case
    A -> "a"
    B -> "b"
    C -> "c"
    D -> "d"
    E -> "e"
    F -> "f"
    G -> "g"
    H -> "h"
    I -> "i"
    J -> "j"
    K -> "k"
    L -> "l"
    M -> "m"
    N -> "n"
    O -> "o"
    P -> "p"
    Q -> "q"
    R -> "r"
    S -> "s"
    T -> "t"
    U -> "u"
    V -> "v"
    W -> "w"
    X -> "x"
    Y -> "y"
    Z -> "z"
    One -> "1"
    Two -> "2"
    Three -> "3"
    Four -> "4"
    Five -> "5"
    Six -> "6"
    Seven -> "7"
    Eight -> "8"
    Nine -> "9"
    Zero -> "0"
    Spacebar -> "spacebar"
    Backspace -> "delete_or_backspace"
    OpenBracket -> "open_bracket"
    CloseBracket -> "close_bracket"
    RightArrow -> "right_arrow"
    LeftArrow -> "left_arrow"
    DownArrow -> "down_arrow"
    UpArrow -> "up_arrow"
    ReturnOrEnter -> "return_or_enter"
    Tab -> "tab"
    Comma -> "comma"
    Semicolon -> "semicolon"

instance ToJSON KeyCode where
  toJSON = keyCodeToString
