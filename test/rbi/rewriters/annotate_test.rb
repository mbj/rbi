# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class AnnotateTest < Minitest::Test
    def test_add_annotation_to_root_nodes
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          class B
            def m; end
          end
        end

        class C < T::Struct
          const :c, String
        end
      RBI

      rbi.annotate!("test")

      assert_equal(<<~RBI, rbi.string)
        # @test
        module A
          class B
            def m; end
          end
        end

        # @test
        class C < T::Struct
          const :c, String
        end
      RBI
    end

    def test_add_annotation_to_all_scopes
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          FOO = type_member

          class B
            attr_reader :a

            def m1; end
            def self.m2; end
          end
        end

        class C < T::Struct
          const :a, String
          prop :b, String
        end
      RBI

      rbi.annotate!("test", annotate_scopes: true)

      assert_equal(<<~RBI, rbi.string)
        # @test
        module A
          FOO = type_member

          # @test
          class B
            attr_reader :a
            def m1; end
            def self.m2; end
          end
        end

        # @test
        class C < T::Struct
          const :a, String
          prop :b, String
        end
      RBI
    end

    def test_add_annotation_to_all_properties
      rbi = RBI::Parser.parse_string(<<~RBI)
        # Root scope are always annotated
        module A
          FOO = type_member

          class B
            attr_reader :a

            def m1; end
            def self.m2; end
          end
        end

        # Root scope are always annotated
        class C < T::Struct
          const :a, String
          prop :b, String
        end
      RBI

      rbi.annotate!("test", annotate_properties: true)

      assert_equal(<<~RBI, rbi.string)
        # Root scope are always annotated
        # @test
        module A
          # @test
          FOO = type_member

          class B
            # @test
            attr_reader :a

            # @test
            def m1; end

            # @test
            def self.m2; end
          end
        end

        # Root scope are always annotated
        # @test
        class C < T::Struct
          # @test
          const :a, String

          # @test
          prop :b, String
        end
      RBI
    end

    def test_add_annotation_to_all_nodes
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          FOO = type_member

          class B
            attr_reader :a

            def m1; end
            def self.m2; end
          end
        end

        class C < T::Struct
          const :a, String
          prop :b, String
        end
      RBI

      rbi.annotate!("test", annotate_scopes: true, annotate_properties: true)

      assert_equal(<<~RBI, rbi.string)
        # @test
        module A
          # @test
          FOO = type_member

          # @test
          class B
            # @test
            attr_reader :a

            # @test
            def m1; end

            # @test
            def self.m2; end
          end
        end

        # @test
        class C < T::Struct
          # @test
          const :a, String

          # @test
          prop :b, String
        end
      RBI
    end

    def test_does_not_reannotate_already_annotated_nodes
      rbi = RBI::Parser.parse_string(<<~RBI)
        # @test
        module A
          # @test
          class B
            # @test
            def m1; end
          end
        end
      RBI

      rbi.annotate!("test", annotate_scopes: true, annotate_properties: true)

      assert_equal(<<~RBI, rbi.string)
        # @test
        module A
          # @test
          class B
            # @test
            def m1; end
          end
        end
      RBI
    end

    def test_add_different_annotation_to_nodes
      rbi = RBI::Parser.parse_string(<<~RBI)
        # @test
        module A
          # @test
          class B
            # @test
            def m1; end
          end
        end
      RBI

      rbi.annotate!("other", annotate_scopes: true, annotate_properties: true)

      assert_equal(<<~RBI, rbi.string)
        # @test
        # @other
        module A
          # @test
          # @other
          class B
            # @test
            # @other
            def m1; end
          end
        end
      RBI
    end
  end
end
