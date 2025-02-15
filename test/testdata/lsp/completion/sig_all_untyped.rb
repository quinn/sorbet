# typed: true
extend T::Sig

# For this method, we did not "guess something useful" (all the params +
# return are untyped) so we would not usually emit an autocorrect suggesting
# this sig. But when suggesting a sig for completion specifically, we suggest
# the sig unconditionally, so that it at least gives users something to start
# filling in the holes.

sig # error: Signature declarations expect a block
#  ^ apply-completion: [A] item: 0
def all_untyped(x)
  T.unsafe(nil)
end
