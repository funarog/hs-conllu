module ConlluParser where

{--

 CoNLL-U parsed file reader.  CoNLL format is defined here:
 https://web.archive.org/web/20161105025307/http://ilk.uvt.nl/conll/
 CoNLL-U/UD format is defined here:
 http://universaldependencies.org/format.html
 http://universaldependencies.org/v2/conll-u.html

-- TODO: Convert String -> Text

-- TODO: warn of spaces in fields where they are not allowed (FORM and
-- LEMMA). do this in symbol function.

-- TODO: check what's the purpose of the '_' in this MISC field:
-- '_|SpaceAfter=Yes' should it be allowed?

-- TODO: create non validating parser: count 10 (stringNot "\t\n" <* tab)

--}

---
-- imports

-- lib imports
import UD

-- stdlib
import Control.Monad
import Data.Char
import Data.List
import Data.Maybe
import System.Environment
import System.IO

-- hackage
import Text.Parsec hiding (token)
import Text.Parsec.Combinator
import Text.Parsec.String
import Text.ParserCombinators.Parsec.Char

---
-- conllu parsers
document :: Parser [Sentence]
document = endBy1 sentence blankLine <* eof

blankLine :: Parser ()
blankLine = litSpaces <* newline -- spaces shouldn't exist, but no
                                    -- problem being lax here (I think)

sentence :: Parser Sentence
sentence = liftM2 Sentence (many comment) (many1 token)

comment :: Parser Comment
comment = do char '#'
             commentPair <* newline

token :: Parser Token
-- check liftM5 and above for no variable parsing, see
-- graham's book
token = mkToken <$> index
             <*> optionMaybe indexSep
             <*> optionMaybe index <* tab
             <*> formP <* tab
             <*> lemmaP <* tab
             <*> upostagP <* tab
             <*> xpostagP <* tab
             <*> featsP <* tab
             <*> depheadP <* tab
             <*> deprelP <* tab
             <*> depsP <* tab
             <*> miscP <* newline

emptyField :: Parser (Maybe a)
emptyField = do char '_'
                return Nothing

index :: Parser Index
index = do ix <- many1 digit
           return (read ix :: Index)

indexSep :: Parser IxSep
indexSep = choice [char '-', char '.']

formP :: Parser Form
formP = maybeEmpty stringWSpaces

lemmaP :: Parser Lemma
lemmaP = maybeEmpty stringWSpaces

upostagP :: Parser PosTag
upostagP = maybeEmpty upostagP'
  where
    upostagP' :: Parser Pos
    upostagP' = liftM mkPos stringWOSpaces

xpostagP :: Parser Xpostag
xpostagP = maybeEmpty stringWOSpaces

featsP :: Parser Feats
featsP = listP $ listPair '=' (stringNot "=") (stringNot "\t|")

depheadP :: Parser Dephead
depheadP = maybeEmpty $ symbol index

deprelP :: Parser DepRel
deprelP = maybeEmpty deprelP'

deprelP' :: Parser (Dep, Subtype)
deprelP' = do dep <- depP
              st  <- option [] $ char ':' *> many1 letter
              return (dep,st)
  where
    depP :: Parser Dep
    depP = liftM mkDep $ many1 letter

depsP :: Parser Deps
depsP = listP $ listPair ':' index deprelP'

miscP :: Parser Misc
miscP = maybeEmpty stringWSpaces

---
-- utility parsers
litSpaces :: Parser ()
-- because spaces consumes \t and \n
litSpaces = skipMany $ char ' '

commentPair :: Parser Comment
commentPair =
  keyValue '=' (stringNot "=\n\t") (option [] stringWSpaces)

listPair :: Char -> Parser a -> Parser b -> Parser [(a, b)]
listPair sep p q = sepBy1 (keyValue sep p q) (char '|')

stringNot :: String -> Parser String
-- [ ] second litSpaces in symbol is redundant
stringNot s = symbol . many1 $ noneOf s

stringWSpaces :: Parser String
stringWSpaces = stringNot "\t\n"

stringWOSpaces :: Parser String
stringWOSpaces = stringNot " \t\n"

---
-- parser combinators
keyValue :: Char -> Parser a -> Parser b -> Parser (a, b)
keyValue sep p q = do key   <- p
                      optional $ char sep
                      value <- q
                      return (key, value)

symbol :: Parser a -> Parser a
symbol p = litSpaces *> p <* litSpaces

maybeEmpty :: Parser a -> Parser (Maybe a)
maybeEmpty p = emptyField <|> liftM Just p

listP :: Parser [a] -> Parser [a]
-- using a parser that returns a possibly empty list like sepBy and
-- many will return the correct result for the empty filed ('_'), but
-- will report it the same as any other syntax error
listP p = liftM (fromMaybe []) $ maybeEmpty p
