# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class PrinterTest < Minitest::Test
    def test_print_files_without_strictness
      file = RBI::File.new
      file.root << RBI::Module.new("Foo")

      assert_equal(<<~RBI, file.string)
        module Foo; end
      RBI
    end

    def test_print_files_with_strictness
      file = RBI::File.new(strictness: "true")
      file.root << RBI::Module.new("Foo")

      assert_equal(<<~RBI, file.string)
        # typed: true

        module Foo; end
      RBI
    end

    def test_print_modules_and_classes
      rbi = RBI::Tree.new
      rbi << RBI::Module.new("Foo")
      rbi << RBI::Class.new("Bar")
      rbi << RBI::Class.new("Baz", superclass_name: "Bar")
      rbi << RBI::SingletonClass.new

      assert_equal(<<~RBI, rbi.string)
        module Foo; end
        class Bar; end
        class Baz < Bar; end
        class << self; end
      RBI
    end

    def test_print_nested_scopes
      scope1 = RBI::Module.new("Foo")
      scope2 = RBI::Class.new("Bar")
      scope3 = RBI::Class.new("Baz", superclass_name: "Bar")
      scope4 = RBI::SingletonClass.new

      rbi = RBI::Tree.new
      rbi << scope1
      scope1 << scope2
      scope2 << scope3
      scope3 << scope4

      assert_equal(<<~RBI, rbi.string)
        module Foo
          class Bar
            class Baz < Bar
              class << self; end
            end
          end
        end
      RBI
    end

    def test_print_structs
      rbi = RBI::Tree.new do |tree|
        tree << RBI::Struct.new("Foo", members: [:foo, :bar])
        tree << RBI::Struct.new("Bar", members: [:bar], keyword_init: true) do |struct1|
          struct1 << RBI::Method.new("bar_method")
        end
        tree << RBI::Struct.new("Baz", members: [:baz], keyword_init: false) do |struct2|
          struct2 << RBI::Method.new("baz_method")
          struct2 << RBI::SingletonClass.new do |singleton_class|
            singleton_class << RBI::Method.new("baz_class_method")
          end
        end
      end

      assert_equal(<<~RBI, rbi.string)
        Foo = ::Struct.new(:foo, :bar)

        Bar = ::Struct.new(:bar, keyword_init: true) do
          def bar_method; end
        end

        Baz = ::Struct.new(:baz) do
          def baz_method; end

          class << self
            def baz_class_method; end
          end
        end
      RBI
    end

    def test_print_constants
      rbi = RBI::Tree.new
      rbi << RBI::Const.new("Foo", "42")
      rbi << RBI::Const.new("Bar", "'foo'")
      rbi << RBI::Const.new("Baz", "Bar")

      assert_equal(<<~RBI, rbi.string)
        Foo = 42
        Bar = 'foo'
        Baz = Bar
      RBI
    end

    def test_print_attributes
      rbi = RBI::Tree.new
      rbi << RBI::AttrReader.new(:m1)
      rbi << RBI::AttrWriter.new(:m2, :m3, visibility: Public.new)
      rbi << RBI::AttrAccessor.new(:m4, visibility: Private.new)
      rbi << RBI::AttrReader.new(:m5, visibility: Protected.new)

      assert_equal(<<~RBI, rbi.string)
        attr_reader :m1
        attr_writer :m2, :m3
        private attr_accessor :m4
        protected attr_reader :m5
      RBI
    end

    def test_print_methods
      rbi = RBI::Tree.new
      rbi << RBI::Method.new("m1")
      rbi << RBI::Method.new("m2", visibility: Public.new)
      rbi << RBI::Method.new("m3", visibility: Private.new)
      rbi << RBI::Method.new("m4", visibility: Protected.new)
      rbi << RBI::Method.new("m5", is_singleton: true)
      rbi << RBI::Method.new("m6", is_singleton: true, visibility: Private.new) # TODO: avoid this?

      assert_equal(<<~RBI, rbi.string)
        def m1; end
        def m2; end
        private def m3; end
        protected def m4; end
        def self.m5; end
        private def self.m6; end
      RBI
    end

    def test_print_methods_with_parameters
      method = RBI::Method.new("foo")
      method << RBI::ReqParam.new("a")
      method << RBI::OptParam.new("b", "42")
      method << RBI::RestParam.new("c")
      method << RBI::KwParam.new("d")
      method << RBI::KwOptParam.new("e", "'bar'")
      method << RBI::KwRestParam.new("f")
      method << RBI::BlockParam.new("g")

      assert_equal(<<~RBI, method.string)
        def foo(a, b = 42, *c, d:, e: 'bar', **f, &g); end
      RBI
    end

    def test_print_attributes_with_signatures
      sig1 = RBI::Sig.new

      sig2 = RBI::Sig.new(return_type: "R")
      sig2 << RBI::SigParam.new("a", "A")
      sig2 << RBI::SigParam.new("b", "T.nilable(B)")
      sig2 << RBI::SigParam.new("b", "T.proc.void")

      sig3 = RBI::Sig.new(is_abstract: true)
      sig3.is_override = true
      sig3.is_overridable = true

      sig4 = RBI::Sig.new(return_type: "T.type_parameter(:V)")
      sig4.type_params << "U"
      sig4.type_params << "V"
      sig4 << RBI::SigParam.new("a", "T.type_parameter(:U)")

      attr = RBI::AttrAccessor.new(:foo, :bar)
      attr.sigs << sig1
      attr.sigs << sig2
      attr.sigs << sig3
      attr.sigs << sig4

      assert_equal(<<~RBI, attr.string)
        sig { void }
        sig { params(a: A, b: T.nilable(B), b: T.proc.void).returns(R) }
        sig { abstract.override.overridable.void }
        sig { type_parameters(:U, :V).params(a: T.type_parameter(:U)).returns(T.type_parameter(:V)) }
        attr_accessor :foo, :bar
      RBI
    end

    def test_print_methods_with_signatures
      sig1 = RBI::Sig.new

      sig2 = RBI::Sig.new(return_type: "R")
      sig2 << RBI::SigParam.new("a", "A")
      sig2 << RBI::SigParam.new("b", "T.nilable(B)")
      sig2 << RBI::SigParam.new("b", "T.proc.void")

      sig3 = RBI::Sig.new(is_abstract: true)
      sig3.is_override = true
      sig3.is_overridable = true
      sig3.checked = :never

      sig4 = RBI::Sig.new(return_type: "T.type_parameter(:V)")
      sig4.type_params << "U"
      sig4.type_params << "V"
      sig4 << RBI::SigParam.new("a", "T.type_parameter(:U)")

      method = RBI::Method.new("foo")
      method.sigs << sig1
      method.sigs << sig2
      method.sigs << sig3
      method.sigs << sig4

      assert_equal(<<~RBI, method.string)
        sig { void }
        sig { params(a: A, b: T.nilable(B), b: T.proc.void).returns(R) }
        sig { abstract.override.overridable.void.checked(:never) }
        sig { type_parameters(:U, :V).params(a: T.type_parameter(:U)).returns(T.type_parameter(:V)) }
        def foo; end
      RBI
    end

    def test_print_mixins
      scope = RBI::Class.new("Foo")
      scope << RBI::Include.new("A")
      scope << RBI::Extend.new("A", "B")

      assert_equal(<<~RBI, scope.string)
        class Foo
          include A
          extend A, B
        end
      RBI
    end

    def test_print_visibility_labels
      tree = RBI::Tree.new
      tree << RBI::Public.new
      tree << RBI::Method.new("m1")
      tree << RBI::Protected.new
      tree << RBI::Method.new("m2")
      tree << RBI::Private.new
      tree << RBI::Method.new("m3")

      assert_equal(<<~RBI, tree.string)
        public
        def m1; end
        protected
        def m2; end
        private
        def m3; end
      RBI
    end

    def test_print_t_structs
      struct = RBI::TStruct.new("Foo")
      struct << RBI::TStructConst.new("a", "A")
      struct << RBI::TStructConst.new("b", "B", default: "B.new")
      struct << RBI::TStructProp.new("c", "C")
      struct << RBI::TStructProp.new("d", "D", default: "D.new")
      struct << RBI::Method.new("foo")

      assert_equal(<<~RBI, struct.string)
        class Foo < ::T::Struct
          const :a, A
          const :b, B, default: B.new
          prop :c, C
          prop :d, D, default: D.new
          def foo; end
        end
        RBI
    end

    def test_print_t_enums
      rbi = RBI::TEnum.new("Foo")
      block = TEnumBlock.new(["A", "B"])
      block.names << "C"
      rbi << block
      rbi << RBI::Method.new("baz")

      assert_equal(<<~RBI, rbi.string)
        class Foo < ::T::Enum
          enums do
            A = new
            B = new
            C = new
          end
          def baz; end
        end
      RBI
    end

    def test_print_sorbet_helpers
      rbi = RBI::Class.new("Foo")
      rbi << RBI::Helper.new("foo")
      rbi << RBI::Helper.new("sealed")
      rbi << RBI::Helper.new("interface")
      rbi << RBI::MixesInClassMethods.new("A")

      assert_equal(<<~RBI, rbi.string)
        class Foo
          foo!
          sealed!
          interface!
          mixes_in_class_methods A
        end
      RBI
    end

    def test_print_sorbet_type_members_and_templates
      rbi = RBI::Class.new("Foo")
      rbi << RBI::TypeMember.new("A", "type_member")
      rbi << RBI::TypeMember.new("B", "type_template")

      assert_equal(<<~RBI, rbi.string)
        class Foo
          A = type_member
          B = type_template
        end
      RBI
    end

    def test_print_files_with_comments_but_no_strictness
      comments = [
        RBI::Comment.new("This is a"),
        RBI::Comment.new("Multiline Comment"),
      ]

      file = RBI::File.new(comments: comments)
      file.root << RBI::Module.new("Foo")

      assert_equal(<<~RBI, file.string)
        # This is a
        # Multiline Comment

        module Foo; end
      RBI
    end

    def test_print_with_comments_and_strictness
      comments = [
        RBI::Comment.new("This is a"),
        RBI::Comment.new("Multiline Comment"),
      ]

      file = RBI::File.new(strictness: "true", comments: comments)
      file.root << RBI::Module.new("Foo")

      assert_equal(<<~RBI, file.string)
        # typed: true

        # This is a
        # Multiline Comment

        module Foo; end
      RBI
    end

    def test_print_nodes_with_comments
      comments_single = [RBI::Comment.new("This is a single line comment")]

      comments_multi = [
        RBI::Comment.new("This is a"),
        RBI::Comment.new("Multiline Comment"),
      ]

      rbi = RBI::Tree.new
      rbi << RBI::Module.new("Foo", comments: comments_single)
      rbi << RBI::Class.new("Bar", comments: comments_multi)
      rbi << RBI::SingletonClass.new(comments: comments_single)
      rbi << RBI::Const.new("Foo", "42", comments: comments_multi)
      rbi << RBI::Include.new("A", comments: comments_single)
      rbi << RBI::Extend.new("A", comments: comments_multi)

      rbi << RBI::Public.new(comments: comments_single)
      rbi << RBI::Protected.new(comments: comments_single)
      rbi << RBI::Private.new(comments: comments_single)

      struct = RBI::TStruct.new("Foo", comments: comments_single)
      struct << RBI::TStructConst.new("a", "A", comments: comments_multi)
      struct << RBI::TStructProp.new("c", "C", comments: comments_single)
      rbi << struct

      enum = RBI::TEnum.new("Foo", comments: comments_multi)
      enum << TEnumBlock.new(["A", "B"], comments: comments_single)
      rbi << enum

      rbi << RBI::Helper.new("foo", comments: comments_multi)
      rbi << RBI::MixesInClassMethods.new("A", comments: comments_single)
      rbi << RBI::TypeMember.new("A", "type_member", comments: comments_multi)
      rbi << RBI::TypeMember.new("B", "type_template", comments: comments_single)

      assert_equal(<<~RBI, rbi.string)
        # This is a single line comment
        module Foo; end

        # This is a
        # Multiline Comment
        class Bar; end

        # This is a single line comment
        class << self; end

        # This is a
        # Multiline Comment
        Foo = 42

        # This is a single line comment
        include A

        # This is a
        # Multiline Comment
        extend A

        # This is a single line comment
        public

        # This is a single line comment
        protected

        # This is a single line comment
        private

        # This is a single line comment
        class Foo < ::T::Struct
          # This is a
          # Multiline Comment
          const :a, A

          # This is a single line comment
          prop :c, C
        end

        # This is a
        # Multiline Comment
        class Foo < ::T::Enum
          # This is a single line comment
          enums do
            A = new
            B = new
          end
        end

        # This is a
        # Multiline Comment
        foo!

        # This is a single line comment
        mixes_in_class_methods A

        # This is a
        # Multiline Comment
        A = type_member

        # This is a single line comment
        B = type_template
      RBI
    end

    def test_print_nodes_with_multiline_comments
      comments = [RBI::Comment.new("This is a\nmultiline comment")]

      rbi = RBI::Tree.new do |tree|
        tree << RBI::Module.new("Foo", comments: comments) do |mod|
          mod << RBI::TypeMember.new("A", "type_member", comments: comments)
          mod << RBI::Method.new("foo", comments: comments)
        end
      end

      rbi << RBI::Method.new("foo", comments: comments) do |method|
        method << RBI::ReqParam.new("a", comments: comments)
        method << RBI::OptParam.new("b", "42", comments: comments)
        method << RBI::RestParam.new("c", comments: comments)
        method << RBI::KwParam.new("d", comments: comments)
        method << RBI::KwOptParam.new("e", "'bar'", comments: comments)
        method << RBI::KwRestParam.new("f", comments: comments)
        method << RBI::BlockParam.new("g", comments: comments)

        sig = RBI::Sig.new
        sig << RBI::SigParam.new("a", "Integer", comments: comments)
        sig << RBI::SigParam.new("b", "String", comments: comments)
        sig << RBI::SigParam.new("c", "T.untyped", comments: comments)
        method.sigs << sig
      end

      assert_equal(<<~RBI, rbi.string)
        # This is a
        # multiline comment
        module Foo
          # This is a
          # multiline comment
          A = type_member

          # This is a
          # multiline comment
          def foo; end
        end

        # This is a
        # multiline comment
        sig do
          params(
            a: Integer, # This is a
                        # multiline comment
            b: String, # This is a
                       # multiline comment
            c: T.untyped # This is a
                         # multiline comment
          ).void
        end
        def foo(
          a, # This is a
             # multiline comment
          b = 42, # This is a
                  # multiline comment
          *c, # This is a
              # multiline comment
          d:, # This is a
              # multiline comment
          e: 'bar', # This is a
                    # multiline comment
          **f, # This is a
               # multiline comment
          &g # This is a
             # multiline comment
        ); end
      RBI
    end

    def test_print_nodes_with_heredoc_comments
      comments = [RBI::Comment.new(<<~COMMENT)]
        This
        is
        a
        multiline
        comment
      COMMENT

      rbi = RBI::Tree.new do |tree|
        tree << RBI::Module.new("Foo", comments: comments)
      end

      assert_equal(<<~RBI, rbi.string)
        # This
        # is
        # a
        # multiline
        # comment
        module Foo; end
      RBI
    end

    def test_print_methods_with_signatures_and_comments
      comments_single = [RBI::Comment.new("This is a single line comment")]

      comments_multi = [
        RBI::Comment.new("This is a"),
        RBI::Comment.new("Multiline Comment"),
      ]

      rbi = RBI::Tree.new
      rbi << RBI::Method.new("foo", comments: comments_multi)

      method = RBI::Method.new("foo", comments: comments_single)
      method.sigs << RBI::Sig.new
      rbi << method

      sig1 = RBI::Sig.new
      sig2 = RBI::Sig.new(return_type: "R")
      sig2 << RBI::SigParam.new("a", "A")
      sig2 << RBI::SigParam.new("b", "T.nilable(B)")
      sig2 << RBI::SigParam.new("b", "T.proc.void")

      method = RBI::Method.new("bar", comments: comments_multi)
      method.sigs << sig1
      method.sigs << sig2
      rbi << method

      assert_equal(<<~RBI, rbi.string)
        # This is a
        # Multiline Comment
        def foo; end

        # This is a single line comment
        sig { void }
        def foo; end

        # This is a
        # Multiline Comment
        sig { void }
        sig { params(a: A, b: T.nilable(B), b: T.proc.void).returns(R) }
        def bar; end
      RBI
    end

    def test_print_tree_header_comments
      rbi = RBI::Tree.new(comments: [
        RBI::Comment.new("typed: true"),
        RBI::Comment.new("frozen_string_literal: false"),
      ])
      rbi << RBI::Module.new("Foo", comments: [RBI::Comment.new("Foo comment")])

      assert_equal(<<~RBI, rbi.string)
        # typed: true
        # frozen_string_literal: false

        # Foo comment
        module Foo; end
      RBI
    end

    def test_print_empty_comments
      tree = RBI::Tree.new(comments: [
        RBI::Comment.new("typed: true"),
        RBI::Comment.new(""),
        RBI::Comment.new("Some intro comment"),
        RBI::Comment.new("Some other comment"),
      ])

      assert_equal(<<~RBI, tree.string)
        # typed: true
        #
        # Some intro comment
        # Some other comment
      RBI
    end

    def test_print_empty_trees_with_comments
      rbi = RBI::File.new(strictness: "true")
      rbi.root.comments << RBI::Comment.new("foo")

      assert_equal(<<~RBI, rbi.string)
        # typed: true

        # foo
      RBI
    end

    def test_print_params_inline_comments
      comments = [RBI::Comment.new("comment")]

      method = RBI::Method.new("foo", comments: comments)
      method << RBI::ReqParam.new("a", comments: comments)
      method << RBI::OptParam.new("b", "42", comments: comments)
      method << RBI::RestParam.new("c", comments: comments)
      method << RBI::KwParam.new("d", comments: comments)
      method << RBI::KwOptParam.new("e", "'bar'", comments: comments)
      method << RBI::KwRestParam.new("f", comments: comments)
      method << RBI::BlockParam.new("g", comments: comments)

      assert_equal(<<~RBI, method.string)
        # comment
        def foo(
          a, # comment
          b = 42, # comment
          *c, # comment
          d:, # comment
          e: 'bar', # comment
          **f, # comment
          &g # comment
        ); end
      RBI
    end

    def test_print_params_multiline_comments
      comments = [
        RBI::Comment.new("comment 1"),
        RBI::Comment.new("comment 2"),
      ]

      method = RBI::Method.new("foo", comments: comments)
      method << RBI::ReqParam.new("a", comments: comments)
      method << RBI::OptParam.new("b", "42", comments: comments)
      method << RBI::RestParam.new("c", comments: comments)
      method << RBI::KwParam.new("d", comments: comments)
      method << RBI::KwOptParam.new("e", "'bar'", comments: comments)
      method << RBI::KwRestParam.new("f", comments: comments)
      method << RBI::BlockParam.new("g", comments: comments)

      assert_equal(<<~RBI, method.string)
        # comment 1
        # comment 2
        def foo(
          a, # comment 1
             # comment 2
          b = 42, # comment 1
                  # comment 2
          *c, # comment 1
              # comment 2
          d:, # comment 1
              # comment 2
          e: 'bar', # comment 1
                    # comment 2
          **f, # comment 1
               # comment 2
          &g # comment 1
             # comment 2
        ); end
      RBI
    end

    def test_print_sig_params_inline_comments
      comments = [RBI::Comment.new("comment")]

      sig = RBI::Sig.new
      sig << RBI::SigParam.new("a", "Integer", comments: comments)
      sig << RBI::SigParam.new("b", "String", comments: comments)
      sig << RBI::SigParam.new("c", "T.untyped", comments: comments)

      assert_equal(<<~RBI, sig.string)
        sig do
          params(
            a: Integer, # comment
            b: String, # comment
            c: T.untyped # comment
          ).void
        end
      RBI
    end

    def test_print_sig_params_multiline_comments
      comments = [
        RBI::Comment.new("comment 1"),
        RBI::Comment.new("comment 2"),
      ]

      sig = RBI::Sig.new
      sig << RBI::SigParam.new("a", "Integer", comments: comments)
      sig << RBI::SigParam.new("b", "String", comments: comments)
      sig << RBI::SigParam.new("c", "T.untyped", comments: comments)

      assert_equal(<<~RBI, sig.string)
        sig do
          params(
            a: Integer, # comment 1
                        # comment 2
            b: String, # comment 1
                       # comment 2
            c: T.untyped # comment 1
                         # comment 2
          ).void
        end
      RBI
    end

    def test_print_blank_lines
      comments = [
        RBI::Comment.new("comment 1"),
        BlankLine.new,
        RBI::Comment.new("comment 2"),
      ]

      rbi = Module.new("Foo", comments: comments) do |mod|
        mod << BlankLine.new
        mod << RBI::Method.new("foo")
        mod << BlankLine.new
        mod << BlankLine.new
        mod << BlankLine.new

        mod << Class.new("Bar") do |cls|
          cls << RBI::Comment.new("begin")
          cls << BlankLine.new
          cls << BlankLine.new
          cls << RBI::Comment.new("middle")
          cls << BlankLine.new
          cls << BlankLine.new
          cls << RBI::Comment.new("end")
        end
      end

      assert_equal(<<~RBI, rbi.string)
        # comment 1

        # comment 2
        module Foo

          def foo; end



          class Bar
            # begin


            # middle


            # end
          end
        end
      RBI
    end

    def test_print_new_lines_between_scopes
      rbi = RBI::Tree.new
      scope = RBI::Class.new("Bar")
      scope << RBI::Include.new("ModuleA")
      rbi << scope
      rbi << RBI::Module.new("ModuleA")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        class Bar
          include ModuleA
        end

        module ModuleA; end
      RBI
    end

    def test_print_new_lines_between_methods_with_sigs
      rbi = RBI::Tree.new
      rbi << RBI::Method.new("m1")
      rbi << RBI::Method.new("m2")

      m3 = RBI::Method.new("m3")
      m3.sigs << RBI::Sig.new
      rbi << m3

      rbi << RBI::Method.new("m4")

      m5 = RBI::Method.new("m5")
      m5.sigs << RBI::Sig.new
      m5.sigs << RBI::Sig.new
      rbi << m5

      m6 = RBI::Method.new("m6")
      m6.sigs << RBI::Sig.new
      rbi << m6

      rbi << RBI::Method.new("m7")
      rbi << RBI::Method.new("m8")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        def m1; end
        def m2; end

        sig { void }
        def m3; end

        def m4; end

        sig { void }
        sig { void }
        def m5; end

        sig { void }
        def m6; end

        def m7; end
        def m8; end
      RBI
    end

    def test_print_nodes_locations
      loc = RBI::Loc.new(file: "file.rbi", begin_line: 1, end_line: 2, begin_column: 3, end_column: 4)

      rbi = RBI::Tree.new(loc: loc)
      rbi << RBI::Module.new("S1", loc: loc)
      rbi << RBI::Class.new("S2", loc: loc)
      rbi << RBI::SingletonClass.new(loc: loc)
      rbi << RBI::TEnum.new("TE", loc: loc)
      rbi << RBI::TStruct.new("TS", loc: loc)
      rbi << RBI::Const.new("C", "42", loc: loc)
      rbi << RBI::Extend.new("E", loc: loc)
      rbi << RBI::Include.new("I", loc: loc)
      rbi << RBI::MixesInClassMethods.new("MICM", loc: loc)
      rbi << RBI::Helper.new("abstract", loc: loc)
      rbi << RBI::TStructConst.new("SC", "Type", loc: loc)
      rbi << RBI::TStructProp.new("SP", "Type", loc: loc)
      rbi << RBI::Method.new("m1", loc: loc)

      assert_equal(<<~RBI, rbi.string(print_locs: true))
        # file.rbi:1:3-2:4
        module S1; end
        # file.rbi:1:3-2:4
        class S2; end
        # file.rbi:1:3-2:4
        class << self; end
        # file.rbi:1:3-2:4
        class TE < ::T::Enum; end
        # file.rbi:1:3-2:4
        class TS < ::T::Struct; end
        # file.rbi:1:3-2:4
        C = 42
        # file.rbi:1:3-2:4
        extend E
        # file.rbi:1:3-2:4
        include I
        # file.rbi:1:3-2:4
        mixes_in_class_methods MICM
        # file.rbi:1:3-2:4
        abstract!
        # file.rbi:1:3-2:4
        const :SC, Type
        # file.rbi:1:3-2:4
        prop :SP, Type
        # file.rbi:1:3-2:4
        def m1; end
      RBI
    end

    def test_print_sigs_locations
      loc = RBI::Loc.new(file: "file.rbi", begin_line: 1, end_line: 2, begin_column: 3, end_column: 4)

      sig1 = RBI::Sig.new(loc: loc)
      sig2 = RBI::Sig.new(loc: loc)

      rbi = RBI::Tree.new(loc: loc)
      rbi << RBI::Method.new("m1", sigs: [sig1, sig2], loc: loc)

      assert_equal(<<~RBI, rbi.string(print_locs: true))
        # file.rbi:1:3-2:4
        sig { void }
        # file.rbi:1:3-2:4
        sig { void }
        # file.rbi:1:3-2:4
        def m1; end
      RBI
    end
  end
end
