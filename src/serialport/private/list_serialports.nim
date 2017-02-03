{.deadCodeElim:on.}

when defined(windows):
  include ./list_serialports_win
elif defined(macosx):
  # TODO: Mac support
  include ./list_serialports_mac
else:
  {.error: "Unsupported OS".}
