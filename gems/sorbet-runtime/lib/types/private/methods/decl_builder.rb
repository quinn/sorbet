# frozen_string_literal: true
# typed: true

module T::Private::Methods
  Declaration = Struct.new(
    :mod,
    :params,
    :returns,
    :bind,
    :mode,
    :checked,
    :finalized,
    :on_failure,
    :override_allow_incompatible,
    :type_parameters,
    :raw,
    :final
  )

  class DeclBuilder
    # The signature declaration the builder is composing (class `Declaration`)
    attr_reader :decl

    class BuilderError < StandardError; end

    private def check_live!
      if decl.finalized
        raise BuilderError.new("You can't modify a signature declaration after it has been used.")
      end
    end

    private def check_sig_block_is_unset!
      if T::Private::DeclState.current.active_declaration&.blk
        raise BuilderError.new(
          "Cannot add more signature statements after the declaration block."
        )
      end
    end

    # Verify if we're trying to invoke the method outside of a signature block. Notice that we need to check if it's a
    # proc, because this is valid and would lead to a false positive: `T.type_alias { T.proc.params(a: Integer).void }`
    private def check_running_inside_block!(method_name)
      unless @inside_sig_block || decl.mod == T::Private::Methods::PROC_TYPE
        raise BuilderError.new(
          "Can't invoke #{method_name} outside of a signature declaration block"
        )
      end
    end

    def initialize(mod, raw)
      # TODO RUBYPLAT-1278 - with ruby 2.5, use kwargs here
      @decl = Declaration.new(
        mod,
        ARG_NOT_PROVIDED, # params
        ARG_NOT_PROVIDED, # returns
        ARG_NOT_PROVIDED, # bind
        Modes.standard, # mode
        ARG_NOT_PROVIDED, # checked
        false, # finalized
        ARG_NOT_PROVIDED, # on_failure
        nil, # override_allow_incompatible
        ARG_NOT_PROVIDED, # type_parameters
        raw,
        ARG_NOT_PROVIDED, # final
      )
      @inside_sig_block = false
    end

    def run!(&block)
      @inside_sig_block = true
      instance_exec(&block)
      finalize!
      self
    end

    def params(**params)
      check_live!
      check_running_inside_block!(__method__)

      if !decl.params.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't call .params twice")
      end

      if params.empty?
        raise BuilderError.new("params expects keyword arguments")
      end
      decl.params = params

      self
    end

    def returns(type)
      check_live!
      check_running_inside_block!(__method__)

      if decl.returns.is_a?(T::Private::Types::Void)
        raise BuilderError.new("You can't call .returns after calling .void.")
      end
      if !decl.returns.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't call .returns multiple times in a signature.")
      end

      decl.returns = type

      self
    end

    def void
      check_live!
      check_running_inside_block!(__method__)

      if !decl.returns.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't call .void after calling .returns.")
      end

      decl.returns = T::Private::Types::Void.new

      self
    end

    def bind(type)
      check_live!
      check_running_inside_block!(__method__)

      if !decl.bind.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't call .bind multiple times in a signature.")
      end

      decl.bind = type

      self
    end

    def checked(level)
      check_live!
      check_running_inside_block!(__method__)

      if !decl.checked.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't call .checked multiple times in a signature.")
      end
      if (level == :never || level == :compiled) && !decl.on_failure.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't use .checked(:#{level}) with .on_failure because .on_failure will have no effect.")
      end
      if !T::Private::RuntimeLevels::LEVELS.include?(level)
        raise BuilderError.new("Invalid `checked` level '#{level}'. Use one of: #{T::Private::RuntimeLevels::LEVELS}.")
      end

      decl.checked = level

      self
    end

    def on_failure(*args)
      check_live!
      check_running_inside_block!(__method__)

      if !decl.on_failure.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't call .on_failure multiple times in a signature.")
      end
      if decl.checked == :never || decl.checked == :compiled
        raise BuilderError.new("You can't use .on_failure with .checked(:#{decl.checked}) because .on_failure will have no effect.")
      end

      decl.on_failure = args

      self
    end

    def abstract(&blk)
      check_live!

      case decl.mode
      when Modes.standard
        decl.mode = Modes.abstract
      when Modes.abstract
        raise BuilderError.new(".abstract cannot be repeated in a single signature")
      else
        raise BuilderError.new("`.abstract` cannot be combined with `.override` or `.overridable`.")
      end

      check_sig_block_is_unset!

      if blk
        T::Private::DeclState.current.active_declaration.blk = blk
      end

      self
    end

    def final(&blk)
      check_live!

      if !decl.final.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't call .final multiple times in a signature.")
      end

      if @inside_sig_block
        raise BuilderError.new(
          "Unlike other sig annotations, the `final` annotation must remain outside the sig block, " \
          "using either `sig(:final) {...}` or `sig.final {...}`, not `sig {final. ...}"
        )
      end

      raise BuilderError.new(".final cannot be repeated in a single signature") if final?

      decl.final = true

      check_sig_block_is_unset!

      if blk
        T::Private::DeclState.current.active_declaration.blk = blk
      end

      self
    end

    def final?
      !decl.final.equal?(ARG_NOT_PROVIDED) && decl.final
    end

    def override(allow_incompatible: false, &blk)
      check_live!

      case decl.mode
      when Modes.standard
        decl.mode = Modes.override
        decl.override_allow_incompatible = allow_incompatible
      when Modes.override, Modes.overridable_override
        raise BuilderError.new(".override cannot be repeated in a single signature")
      when Modes.overridable
        decl.mode = Modes.overridable_override
      else
        raise BuilderError.new("`.override` cannot be combined with `.abstract`.")
      end

      check_sig_block_is_unset!

      if blk
        T::Private::DeclState.current.active_declaration.blk = blk
      end

      self
    end

    def overridable(&blk)
      check_live!

      case decl.mode
      when Modes.abstract
        raise BuilderError.new("`.overridable` cannot be combined with `.#{decl.mode}`")
      when Modes.override
        decl.mode = Modes.overridable_override
      when Modes.standard
        decl.mode = Modes.overridable
      when Modes.overridable, Modes.overridable_override
        raise BuilderError.new(".overridable cannot be repeated in a single signature")
      end

      check_sig_block_is_unset!

      if blk
        T::Private::DeclState.current.active_declaration.blk = blk
      end

      self
    end

    # Declares valid type paramaters which can be used with `T.type_parameter` in
    # this `sig`.
    #
    # This is used for generic methods. Example usage:
    #
    #  sig do
    #    type_parameters(:U)
    #    .params(blk: T.proc.params(arg0: Elem).returns(T.type_parameter(:U)))
    #    .returns(T::Array[T.type_parameter(:U)])
    #  end
    #  def map(&blk); end
    def type_parameters(*names)
      check_live!
      check_running_inside_block!(__method__)

      names.each do |name|
        raise BuilderError.new("not a symbol: #{name}") unless name.is_a?(Symbol)
      end

      if !decl.type_parameters.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You can't call .type_parameters multiple times in a signature.")
      end

      decl.type_parameters = names

      self
    end

    def finalize!
      check_live!

      if decl.returns.equal?(ARG_NOT_PROVIDED)
        raise BuilderError.new("You must provide a return type; use the `.returns` or `.void` builder methods.")
      end

      if decl.bind.equal?(ARG_NOT_PROVIDED)
        decl.bind = nil
      end
      if decl.checked.equal?(ARG_NOT_PROVIDED)
        default_checked_level = T::Private::RuntimeLevels.default_checked_level
        if (default_checked_level == :never || default_checked_level == :compiled) && !decl.on_failure.equal?(ARG_NOT_PROVIDED)
          raise BuilderError.new("To use .on_failure you must additionally call .checked(:tests) or .checked(:always), otherwise, the .on_failure has no effect.")
        end
        decl.checked = default_checked_level
      end
      if decl.on_failure.equal?(ARG_NOT_PROVIDED)
        decl.on_failure = nil
      end
      if decl.params.equal?(ARG_NOT_PROVIDED)
        decl.params = {}
      end
      if decl.type_parameters.equal?(ARG_NOT_PROVIDED)
        decl.type_parameters = {}
      end

      decl.finalized = true

      self
    end
  end
end
