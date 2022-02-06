module Parse.Construct where

import AST.Source
import Control.Monad (void)
import Parse.Indent (IndentParser)
import Parse.Literal
import Text.Parsec (spaces, try, (<?>))
import qualified Text.Parsec as P
import qualified Text.Parsec.Indent as Indent
import Text.Parsec.Token (reservedOp)
import Text.ParserCombinators.Parsec (Parser, (<|>))

operatorSymbol :: IndentParser Char
operatorSymbol = P.oneOf "!#$%+-/*.<>=?@~\\^|"

letter :: [Char]
letter = ['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['_']

letterOrDigit :: [Char]
letterOrDigit = letter ++ ['0' .. '9']

normalIdentifier :: IndentParser Identifier
normalIdentifier = do
  c <- P.oneOf letter
  cs <- P.many (P.oneOf letterOrDigit)
  return $ NormalIdentifier (c : cs)

identifier :: IndentParser Identifier
identifier = do
  paren <- P.optionMaybe (P.char '(')
  case paren of
    Just _ -> do
      body <- P.many1 operatorSymbol
      _ <- P.char ')'
      return $ OpIdentifier body
    Nothing -> normalIdentifier

type_ :: IndentParser Type
type_ =
  (P.string "()" >> return UnitType)
    <|> (TypeVariable <$> normalIdentifier)

def :: IndentParser Def
def = do
  _ <- P.string "def"
  spaces
  name <- identifier
  spaces
  _ <- P.char ':'
  spaces
  Def name <$> type_

letName :: IndentParser Identifier
letName = do
  _ <- P.string "let"
  spaces
  s <- normalIdentifier
  spaces
  _ <- P.char '='
  spaces
  return s

let_ :: IndentParser Let
let_ = Indent.withPos $ do
  def_ <- P.optionMaybe (def <* P.newline)
  b <- Indent.withBlock ((. Block) . Let def_) letName (line <* spaces)
  spaces
  return b

line :: IndentParser Line
line = linePart
  where
    linePart =
      DefLetLine <$> let_
          <|> ExprLine <$> expression

parseOp :: IndentParser (Expr -> Expr -> Expr)
parseOp = do
  spaces
  symbol <- P.many1 operatorSymbol
  spaces
  return $ BinaryOp symbol

binaryOp :: IndentParser Expr
binaryOp = try $ P.chainl1 literal parseOp

expression :: IndentParser Expr
expression = binaryOp <|> literal

file :: IndentParser [Line]
file = P.manyTill line (try P.eof)
