{-# LANGUAGE RecordWildCards #-}

module Main where

import Control.Monad
import Control.Monad.IO.Class
import Control.Exception (bracket)
import Control.Lens.Operators

import Data.Acid
import Data.Acid.Local (createCheckpointAndClose)
import Data.Acid.Advanced   ( query', update' )

import Happstack.Server
import Happstack.Server.SimpleHTTPS
import Happstack.Server.Compression

import HTML.Index
import HTML.Upload
import FileUtils
import UploadDB
import qualified HTML.Error as Error

httpConf :: Conf
httpConf = nullConf { port = 8082 }

httpsConf :: TLSConf
httpsConf = nullTLSConf
  { tlsPort = 8083
  , tlsCert = "nils.cc.crt"
  , tlsKey  = "nils.key"
  }

uploadDir :: FilePath
uploadDir = "/home/kvitebjorn/Documents/bindrop/files/"

main :: IO ()
main = do
  putStrLn "Starting server..."

  -- HTTP server
  bracket (openLocalState initialUploadDBState)
          (createCheckpointAndClose)
          (\acid ->
            simpleHTTP httpConf (mainRoute acid)) --httpsForward

  -- HTTPS server
  --simpleHTTPS httpsConf mainHttp

mainHttp :: AcidState UploadDB -> ServerPart Response
mainHttp acid = do
  _ <- compressedResponseFilter
  mainRoute acid

httpsForward :: ServerPart Response
httpsForward = withHost $ \h -> uriRest $ \r -> do

  let url = "https://" ++ takeWhile (':' /=) h ++ ":"
                       ++ show (tlsPort httpsConf)
                       ++ r

  seeOther url (toResponse $ "Forwarding to: " ++ url ++ "\n")

mainRoute :: AcidState UploadDB -> ServerPart Response
mainRoute acid =
  do decodeBody myPolicy
     msum [ indexPart acid
          , do -- the "/" index page
            nullDir
            ok $ toResponse index

          , do -- server files from "/static/"
            dir "static" $ serveDirectory DisableBrowsing [] "static"

          , do -- anything else could not be found
            notFound $ toResponse Error.notFound
          ]

myPolicy :: BodyPolicy
myPolicy = (defaultBodyPolicy "/tmp/" (10*10^(6 :: Int)) 1000 1000)

indexPart :: AcidState UploadDB -> ServerPart Response
indexPart acid =
  do method [GET, POST]
     u <- lookFile "fileUpload"
     let uName = getFileName u
     let uPath = getFilePath u
     newName <- liftIO $ moveToRandomFile uploadDir 11 uPath
     let vName = uName
     let vPath = newName
     --TODO: extract content type and make it part of acid

     --acid stuff here
     --create a new one
     file <- update' acid NewUpload
     let fID = file ^. fileID
     --edit the newly created file upload
     mFile <- query' acid (FileByID fID)
     --add case of Nothing
     case mFile of
       (Just f@(FileUpload{..})) -> msum
         [ do method POST
              let updatedFile = f & fpath .~ vPath
                                  & fname .~ vName
              _ <- update' acid (UpdateUpload updatedFile)

              --TODO: routing for download with random name
              --provide a link to /f/randomNameHere in Upload.hs
              --then /f/randomNameHere should give you the file
              ok $ toResponse $ upload updatedFile
         ]
       _ -> mzero -- FIXME

getFilePath :: (FilePath, FilePath, ContentType) -> FilePath
getFilePath (fp, _, _) = fp

getFileName :: (FilePath, FilePath, ContentType) -> FilePath
getFileName (_, name, _) = name

--getFileContents :: (FilePath, FilePath, ContentType) -> FilePath
--getFileContents (_, _, contents) =

