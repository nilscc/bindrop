{-# LANGUAGE OverloadedStrings #-}

module HTML.File where

import Control.Lens.Operators
import Text.Blaze.Html
import Text.Blaze.Html5 as H
import Text.Blaze.Html5.Attributes as A

import HTML.Base
import UploadDB

recentFile :: FileUpload -> Html
recentFile file = baseHtml $ do
  let fileName = file ^. fname
  let fileTime = file ^. uploadTime
  let infoLink = "localhost:8082/f/"    ++ file ^. sfname

  H.p (H.toHtml $ "uploaded name: "     ++ fileName)
  H.p (H.toHtml $ "time of upload: "    ++ show fileTime)
  H.p (H.toHtml $ "link to file info: " ++ infoLink)
