{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Bindings.HDF5.Group
    ( Group

    , createGroup
    , createAnonymousGroup
    , openGroup
    , closeGroup

    , GroupStorageType(..)
    , GroupInfo(..)

    , getGroupInfo
    , getGroupInfoByName
    ) where

import Bindings.HDF5.Core
import Bindings.HDF5.Error
import Bindings.HDF5.Object
import Bindings.HDF5.PropertyList.GAPL
import Bindings.HDF5.PropertyList.GCPL
import Bindings.HDF5.PropertyList.LCPL
import Bindings.HDF5.Raw.H5G
import Bindings.HDF5.Raw.H5I
import Bindings.HDF5.Raw.H5P
import Bindings.HDF5.Raw.Util
import qualified Data.ByteString as BS
import Data.Int
import Foreign.Ptr.Conventions

newtype Group = Group HId_t
    deriving (Eq, HId, FromHId, HDFResultType)

instance Location Group
instance Object Group where
    staticObjectType = Tagged (Just GroupObj)

createGroup :: Location t => t -> BS.ByteString -> Maybe LCPL -> Maybe GCPL -> Maybe GAPL -> IO Group
createGroup loc name lcpl gcpl gapl =
    fmap Group $
        withErrorCheck $
            BS.useAsCString name $ \cname ->
                h5g_create2 (hid loc) cname
                    (maybe h5p_DEFAULT hid lcpl)
                    (maybe h5p_DEFAULT hid gcpl)
                    (maybe h5p_DEFAULT hid gapl)

createAnonymousGroup :: Location t => t -> Maybe GCPL -> Maybe GAPL -> IO Group
createAnonymousGroup loc gcpl gapl =
    fmap Group $
        withErrorCheck $
            h5g_create_anon (hid loc) (maybe h5p_DEFAULT hid gcpl) (maybe h5p_DEFAULT hid gapl)

openGroup :: Location t => t -> BS.ByteString -> Maybe GAPL -> IO Group
openGroup loc name gapl =
    fmap Group $
        withErrorCheck $
            BS.useAsCString name $ \cname ->
                h5g_open2 (hid loc) cname (maybe h5p_DEFAULT hid gapl)

closeGroup :: Group -> IO ()
closeGroup (Group grp) =
    withErrorCheck_ $
        h5g_close grp

data GroupStorageType
    = CompactStorage
    | DenseStorage
    | SymbolTableStorage
    | UnknownStorage
    deriving (Eq, Ord, Read, Show, Enum, Bounded)

groupStorageTypeFromCode :: H5G_storage_type_t -> GroupStorageType
groupStorageTypeFromCode c
    | c == h5g_STORAGE_TYPE_COMPACT         = CompactStorage
    | c == h5g_STORAGE_TYPE_DENSE           = DenseStorage
    | c == h5g_STORAGE_TYPE_SYMBOL_TABLE    = SymbolTableStorage
    | otherwise                             = UnknownStorage

data GroupInfo = GroupInfo
    { groupStorageType  :: !GroupStorageType
    , groupNLinks       :: !HSize
    , groupMaxCOrder    :: !Int64
    , groupMounted      :: !Bool
    } deriving (Eq, Ord, Read, Show)

readGroupInfo :: H5G_info_t -> GroupInfo
readGroupInfo (H5G_info_t a b c d) = GroupInfo (groupStorageTypeFromCode a) (HSize b) c (hboolToBool d)

getGroupInfo :: Group -> IO GroupInfo
getGroupInfo (Group group_id) =
    fmap readGroupInfo $
        withOut_ $ \info ->
            withErrorCheck_ $
                h5g_get_info group_id info

getGroupInfoByName :: Location loc => loc -> BS.ByteString -> Maybe LAPL -> IO GroupInfo
getGroupInfoByName loc name lapl =
    fmap readGroupInfo $
        withOut_ $ \info ->
            BS.useAsCString name $ \cname ->
                withErrorCheck_ $
                    h5g_get_info_by_name (hid loc) cname info (maybe h5p_DEFAULT hid lapl)
