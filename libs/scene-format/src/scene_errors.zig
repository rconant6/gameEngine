pub const LexerError = error{
    InvalidCharacter,
    InvalidColor,
    InvalidIndentation,
    InvalidNumber,
    TabIndentationFound,
    UnclosedString,
};

pub const ParseError = error{
    NoPreviousTokens,
    NoTokenReturned,
    UnclosedArrayBrackets,
    UnexpectedToken,
    Unimplemented,
    UnknownDeclarationType,
    UnknownType,
    UnknownAssetType,
    UnsupportedVectorLength,
} || LexerError || @TypeOf(error.OutOfMemory) || @TypeOf(error.Overflow);

const SceneError = ParseError || LexerError || @TypeOf(error.OutOfMemory) || @TypeOf(error.Overflow);
