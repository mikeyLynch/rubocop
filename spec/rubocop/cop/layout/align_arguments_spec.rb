# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Layout::AlignArguments do
  subject(:cop) { described_class.new(config) }

  let(:config) do
    RuboCop::Config.new('Layout/AlignArguments' => cop_config,
                        'Layout/IndentationWidth' => {
                          'Width' => indentation_width
                        })
  end
  let(:indentation_width) { 2 }

  context 'aligned with first argument' do
    let(:cop_config) do
      {
        'EnforcedStyle' => 'with_first_argument'
      }
    end

    it 'registers an offense for arguments with single indent' do
      expect_offense(<<~RUBY)
        function(a,
          if b then c else d end)
          ^^^^^^^^^^^^^^^^^^^^^^ Align the arguments of a method call if they span more than one line.
      RUBY
    end

    it 'registers an offense for arguments with double indent' do
      expect_offense(<<~RUBY)
        function(a,
            if b then c else d end)
            ^^^^^^^^^^^^^^^^^^^^^^ Align the arguments of a method call if they span more than one line.
      RUBY
    end

    it 'accepts multiline []= method call' do
      expect_no_offenses(<<~RUBY)
        Test.config["something"] =
         true
      RUBY
    end

    it 'accepts correctly aligned arguments' do
      expect_no_offenses(<<~RUBY)
        function(a,
                 0, 1,
                 (x + y),
                 if b then c else d end)
      RUBY
    end

    it 'accepts correctly aligned arguments with fullwidth characters' do
      expect_no_offenses(<<~RUBY)
        f 'Ｒｕｂｙ', g(a,
                        b)
      RUBY
    end

    it 'accepts calls that only span one line' do
      expect_no_offenses('find(path, s, @special[sexp[0]])')
    end

    it "doesn't get confused by a symbol argument" do
      expect_no_offenses(<<~RUBY)
        add_offense(index,
                    MSG % kind)
      RUBY
    end

    it "doesn't get confused by splat operator" do
      expect_offense(<<~RUBY)
        func1(*a,
              *b,
              c)
        func2(a,
             *b,
             ^^ Align the arguments of a method call if they span more than one line.
              c)
        func3(*a)
      RUBY
    end

    it "doesn't get confused by extra comma at the end" do
      expect_offense(<<~RUBY)
        func1(a,
             b,)
             ^ Align the arguments of a method call if they span more than one line.
      RUBY
    end

    it 'can handle a correctly aligned string literal as first argument' do
      expect_no_offenses(<<~RUBY)
        add_offense(x,
                    a)
      RUBY
    end

    it 'can handle a string literal as other argument' do
      expect_no_offenses(<<~RUBY)
        add_offense(
                    "", a)
      RUBY
    end

    it "doesn't get confused by a line break inside a parameter" do
      expect_no_offenses(<<~RUBY)
        read(path, { headers:    true,
                     converters: :numeric })
      RUBY
    end

    it "doesn't get confused by symbols with embedded expressions" do
      expect_no_offenses('send(:"#{name}_comments_path")')
    end

    it "doesn't get confused by regexen with embedded expressions" do
      expect_no_offenses('a(/#{name}/)')
    end

    it 'accepts braceless hashes' do
      expect_no_offenses(<<~RUBY)
        run(collection, :entry_name => label,
                        :paginator  => paginator)
      RUBY
    end

    it 'accepts the first parameter being on a new row' do
      expect_no_offenses(<<~RUBY)
        match(
          a,
          b
        )
      RUBY
    end

    it 'can handle heredoc strings' do
      expect_no_offenses(<<~'RUBY')
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
                    def run_#{name}_callbacks(*args)
                      a = 1
                      return value
                    end
                    EOS
      RUBY
    end

    it 'can handle a method call within a method call' do
      expect_no_offenses(<<~RUBY)
        a(a1,
          b(b1,
            b2),
          a2)
      RUBY
    end

    it 'can handle a call embedded in a string' do
      expect_no_offenses('model("#{index(name)}", child)')
    end

    it 'can handle do-end' do
      expect_no_offenses(<<~RUBY)
        run(lambda do |e|
          w = e['warden']
        end)
      RUBY
    end

    it 'can handle a call with a block inside another call' do
      expect_no_offenses(<<~'RUBY')
        new(table_name,
            exec_query("info('#{row['name']}')").map { |col|
              col['name']
            })
      RUBY
    end

    it 'can handle a ternary condition with a block reference' do
      expect_no_offenses('cond ? a : func(&b)')
    end

    it 'can handle parentheses used with no arguments' do
      expect_no_offenses('func()')
    end

    it 'can handle a multiline hash as second parameter' do
      expect_no_offenses(<<~RUBY)
        tag(:input, {
          :value => value
        })
      RUBY
    end

    it 'can handle method calls without parentheses' do
      expect_no_offenses('a(b c, d)')
    end

    it 'can handle other method calls without parentheses' do
      expect_no_offenses(<<~RUBY)
        chars(Unicode.apply_mapping @wrapped_string, :uppercase)
      RUBY
    end

    it "doesn't crash and burn when there are nested issues" do
      # regression test; see GH issue 2441
      src = <<~RUBY
        build(:house,
          :rooms => [
            build(:bedroom,
              :bed => build(:bed,
                :occupants => [],
                :size => "king"
              )
            )
          ]
        )
      RUBY
      expect { inspect_source(src) }.not_to raise_error
    end

    context 'assigned methods' do
      it 'accepts the first parameter being on a new row' do
        expect_no_offenses(<<~RUBY)
          assigned_value = match(
            a,
            b,
            c
          )
        RUBY
      end

      it 'accepts the first parameter being on method row' do
        expect_no_offenses(<<~RUBY)
          assigned_value = match(a,
                                 b,
                                 c
                           )
        RUBY
      end
    end

    it 'auto-corrects alignment' do
      new_source = autocorrect_source(<<~RUBY)
        func(a,
               b,
        c)
      RUBY
      expect(new_source).to eq(<<~RUBY)
        func(a,
             b,
             c)
      RUBY
    end

    it 'auto-corrects each line of a multi-line parameter to the right' do
      new_source =
        autocorrect_source(<<~RUBY)
          create :transaction, :closed,
                account:          account,
                open_price:       1.29,
                close_price:      1.30
        RUBY
      expect(new_source)
        .to eq(<<~RUBY)
          create :transaction, :closed,
                 account:          account,
                 open_price:       1.29,
                 close_price:      1.30
        RUBY
    end

    it 'auto-corrects each line of a multi-line parameter to the left' do
      new_source =
        autocorrect_source(<<~RUBY)
          create :transaction, :closed,
                   account:          account,
                   open_price:       1.29,
                   close_price:      1.30
        RUBY
      expect(new_source)
        .to eq(<<~RUBY)
          create :transaction, :closed,
                 account:          account,
                 open_price:       1.29,
                 close_price:      1.30
        RUBY
    end

    it 'auto-corrects only arguments that begin a line' do
      original_source = <<~RUBY
        foo(:bar, {
            whiz: 2, bang: 3 }, option: 3)
      RUBY
      new_source = autocorrect_source(original_source)
      expect(new_source).to eq(original_source)
    end

    it 'does not crash in autocorrect on dynamic string in parameter value' do
      src = <<~'RUBY'
        class MyModel < ActiveRecord::Base
          has_many :other_models,
            class_name: "legacy_name",
            order: "#{legacy_name.table_name}.published DESC"

        end
      RUBY
      new_source = autocorrect_source(src)
      expect(new_source)
        .to eq <<~'RUBY'
          class MyModel < ActiveRecord::Base
            has_many :other_models,
                     class_name: "legacy_name",
                     order: "#{legacy_name.table_name}.published DESC"

          end
        RUBY
    end

    context 'when using safe navigation operator' do
      it 'registers an offense for arguments with single indent' do
        expect_offense(<<~RUBY)
          receiver&.function(a,
            if b then c else d end)
            ^^^^^^^^^^^^^^^^^^^^^^ Align the arguments of a method call if they span more than one line.
        RUBY
      end
    end
  end

  context 'aligned with fixed indentation' do
    let(:cop_config) do
      {
        'EnforcedStyle' => 'with_fixed_indentation'
      }
    end

    let(:correct_source) do
      <<~RUBY
        create :transaction, :closed,
          account:     account,
          open_price:  1.29,
          close_price: 1.30
      RUBY
    end

    it 'does not autocorrect correct source' do
      expect(autocorrect_source(correct_source))
        .to eq(correct_source)
    end

    it 'autocorrects by outdenting when indented too far' do
      original_source = <<~RUBY
        create :transaction, :closed,
               account:     account,
               open_price:  1.29,
               close_price: 1.30
      RUBY

      expect(autocorrect_source(original_source))
        .to eq(correct_source)
    end

    it 'autocorrects by indenting when not indented' do
      original_source = <<~RUBY
        create :transaction, :closed,
        account:     account,
        open_price:  1.29,
        close_price: 1.30
      RUBY

      expect(autocorrect_source(original_source))
        .to eq(correct_source)
    end

    it 'autocorrects when first line is indented' do
      original_source = <<-RUBY.strip_margin('|')
        |  create :transaction, :closed,
        |  account:     account,
        |  open_price:  1.29,
        |  close_price: 1.30
      RUBY

      correct_source = <<-RUBY.strip_margin('|')
        |  create :transaction, :closed,
        |    account:     account,
        |    open_price:  1.29,
        |    close_price: 1.30
      RUBY

      expect(autocorrect_source(original_source))
        .to eq(correct_source)
    end

    context 'multi-line method calls' do
      it 'can handle existing indentation from multi-line method calls' do
        expect_no_offenses(<<~RUBY)
          something
            .method_name(
              a,
              b,
              c
            )
        RUBY
      end

      it 'registers offenses for double indentation from relevant method' do
        expect_offense(<<~RUBY)
          something
            .method_name(
                a,
                ^ Use one level of indentation for arguments following the first line of a multi-line method call.
                b,
                ^ Use one level of indentation for arguments following the first line of a multi-line method call.
                c
                ^ Use one level of indentation for arguments following the first line of a multi-line method call.
            )
        RUBY
      end

      it 'does not err on method call without a method name' do
        expect_no_offenses(<<~RUBY)
          something
            .(
              a,
              b,
              c
            )
        RUBY
      end

      it 'autocorrects relative to position of relevant method call' do
        original_source = <<-RUBY.strip_margin('|')
          | something
          |   .method_name(
          |       a,
          |          b,
          |            c
          |   )
        RUBY
        correct_source = <<-RUBY.strip_margin('|')
          | something
          |   .method_name(
          |     a,
          |     b,
          |     c
          |   )
        RUBY
        expect(autocorrect_source(original_source))
          .to eq(correct_source)
      end
    end

    context 'assigned methods' do
      context 'with IndentationWidth:Width set to 4' do
        let(:indentation_width) { 4 }

        it 'accepts the first parameter being on a new row' do
          expect_no_offenses(<<~RUBY)
            assigned_value = match(
                a,
                b,
                c
            )
          RUBY
        end

        it 'accepts the first parameter being on method row' do
          expect_no_offenses(<<~RUBY)
            assigned_value = match(a,
                b,
                c
            )
          RUBY
        end

        it 'autocorrects even when first argument is in wrong position' do
          original_source = <<-RUBY.strip_margin('|')
            | assigned_value = match(
            |         a,
            |            b,
            |                    c
            | )
          RUBY

          correct_source = <<-RUBY.strip_margin('|')
            | assigned_value = match(
            |     a,
            |     b,
            |     c
            | )
          RUBY

          expect(autocorrect_source(original_source))
            .to eq(correct_source)
        end
      end

      context 'with AlignArguments:IndentationWidth set to 4' do
        let(:config) do
          RuboCop::Config.new('Layout/AlignArguments' =>
                              cop_config.merge('IndentationWidth' => 4))
        end

        it 'accepts the first parameter being on a new row' do
          expect_no_offenses(<<~RUBY)
            assigned_value = match(
                a,
                b,
                c
            )
          RUBY
        end

        it 'accepts the first parameter being on method row' do
          expect_no_offenses(<<~RUBY)
            assigned_value = match(a,
                b,
                c
            )
          RUBY
        end
      end
    end
  end
end
