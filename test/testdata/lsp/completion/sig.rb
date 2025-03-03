# typed: true
#        ^ the sigil doesn't have to be strict for this to work

# This test is not an exhaustive list of all the kinds of sigs that could be
# suggested, but instead about what's interesting from an LSP standpoint.

class Normal
  extend T::Sig

  sig # error: Signature declarations expect a block
  #  ^ completion: sig
  #  ^ apply-completion: [A] item: 0
  def nullary_returns_nil
  end

  sig # error: Signature declarations expect a block
  #  ^ completion: sig
  #  ^ apply-completion: [B] item: 0
  def typed_params_and_returns(x)
    1 + x
  end
end

class NoSigInScope
  sig # error: does not exist
  #  ^ completion: (nothing)
# ^^^ error: Signature declarations expect a block
  def no_results_without_extend_tsig; end
end
