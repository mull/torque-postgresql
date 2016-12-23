require 'spec_helper'

RSpec.describe 'Enum', type: :feature do
  let(:connection) { ActiveRecord::Base.connection }

  context 'on migration' do
    it 'can be created' do
      connection.create_enum(:status, %i(foo bar))
      expect(connection.type_exists?(:status)).to be_truthy
      expect(connection.enum_values(:status)).to be_eql(['foo', 'bar'])
    end

    it 'can be deleted' do
      connection.create_enum(:status, %i(foo bar))
      expect(connection.type_exists?(:status)).to be_truthy

      connection.drop_type(:status)
      expect(connection.type_exists?(:status)).to be_falsey
    end

    it 'can be renamed' do
      connection.rename_type(:content_status, :status)
      expect(connection.type_exists?(:content_status)).to be_falsey
      expect(connection.type_exists?(:status)).to be_truthy
    end

    it 'can have prefix' do
      connection.create_enum(:status, %i(foo bar), prefix: true)
      expect(connection.enum_values(:status)).to be_eql(['status_foo', 'status_bar'])
    end

    it 'can have suffix' do
      connection.create_enum(:status, %i(foo bar), suffix: 'tst')
      expect(connection.enum_values(:status)).to be_eql(['foo_tst', 'bar_tst'])
    end

    it 'inserts values at the end' do
      connection.create_enum(:status, %i(foo bar))
      connection.add_enum_values(:status, %i(baz qux))
      expect(connection.enum_values(:status)).to be_eql(['foo', 'bar', 'baz', 'qux'])
    end

    it 'inserts values in the beginning' do
      connection.create_enum(:status, %i(foo bar))
      connection.add_enum_values(:status, %i(baz qux), prepend: true)
      expect(connection.enum_values(:status)).to be_eql(['baz', 'qux', 'foo', 'bar'])
    end

    it 'inserts values in the middle' do
      connection.create_enum(:status, %i(foo bar))
      connection.add_enum_values(:status, %i(baz), after: 'foo')
      expect(connection.enum_values(:status)).to be_eql(['foo', 'baz', 'bar'])

      connection.add_enum_values(:status, %i(qux), before: 'bar')
      expect(connection.enum_values(:status)).to be_eql(['foo', 'baz', 'qux', 'bar'])
    end

    it 'inserts values with prefix or suffix' do
      connection.create_enum(:status, %i(foo bar))
      connection.add_enum_values(:status, %i(baz), prefix: true)
      connection.add_enum_values(:status, %i(qux), suffix: 'tst')
      expect(connection.enum_values(:status)).to be_eql(['foo', 'bar', 'status_baz', 'qux_tst'])
    end
  end

  context 'on table definition' do
    subject { ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition.new('articles') }

    it 'has the enum method' do
      expect(subject).to respond_to(:enum)
    end

    it 'can be used in a single form' do
      subject.enum('content_status')
      expect(subject['content_status'].name).to be_eql('content_status')
      expect(subject['content_status'].type).to be_eql(:content_status)
    end

    it 'can be used in a multiple form' do
      subject.enum('foo', 'bar', 'baz', subtype: :content_status)
      expect(subject['foo'].type).to be_eql(:content_status)
      expect(subject['bar'].type).to be_eql(:content_status)
      expect(subject['baz'].type).to be_eql(:content_status)
    end

    it 'can have custom type' do
      subject.enum('foo', subtype: :content_status)
      expect(subject['foo'].name).to be_eql('foo')
      expect(subject['foo'].type).to be_eql(:content_status)
    end

    it 'raises StatementInvalid when type isn\'t defined' do
      subject.enum('foo')
      creation = connection.schema_creation.accept subject
      expect{ connection.execute creation }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  context 'on schema' do
    it 'dumps when has it' do
      dump_io = StringIO.new
      ActiveRecord::SchemaDumper.dump(connection, dump_io)
      expect(dump_io.string).to match /create_enum \"content_status\", \[/
    end

    it 'do not dump when has none' do
      connection.drop_type(:content_status, force: :cascade)

      dump_io = StringIO.new
      ActiveRecord::SchemaDumper.dump(connection, dump_io)
      expect(dump_io.string).not_to match /create_enum \"content_status\", \[/
    end

    it 'can be used on tables too' do
      dump_io = StringIO.new
      ActiveRecord::SchemaDumper.dump(connection, dump_io)
      expect(dump_io.string).to match /t\.enum +"status", +subtype: :content_status/
    end
  end

  context 'on value' do
    subject { Enum::ContentStatus }
    let(:values) { %w(created draft published archived) }
    let(:error) { Torque::PostgreSQL::Attributes::Enum::EnumError }
    let(:mock_enum) do
      klass = Torque::PostgreSQL::Attributes::Enum.send(:define_from_type, 'mock')
      klass.instance_variable_set(:@values, values << '15')
      klass
    end

    it 'class exists' do
      namespace = Torque::PostgreSQL.config.enum.namespace
      expect(namespace.const_defined?('ContentStatus')).to be_truthy
      expect(subject < Torque::PostgreSQL::Attributes::Enum).to be_truthy
    end

    it 'lazy loads values' do
      expect(subject.instance_variable_defined?(:@values)).to be_falsey
    end

    it 'values match database values' do
      expect(subject.values).to be_eql(values)
    end

    it 'accepts respond_to against value' do
      expect(subject).to respond_to(:archived)
    end

    it 'allows fast creation of values' do
      value = subject.draft
      expect(value).to be_a(subject)
    end

    it 'keeps blank values as nil' do
      expect(subject.new(nil)).to be_nil
      expect(subject.new([])).to be_nil
      expect(subject.new('')).to be_nil
    end

    it 'accepts values to come from numeric' do
      expect(subject.new(0)).to be_eql(subject.created)
      expect { subject.new(5) }.to raise_error(error, /out of bounds/)
    end

    it 'accepts string initialization' do
      expect(subject.new('created')).to be_eql(subject.created)
      expect { subject.new('updated') }.to raise_error(error, /not valid for/)
    end

    it 'allows values comparison' do
      value = subject.draft
      expect(value).to be > subject.created
      expect(value).to be < subject.archived
      expect(value).to_not be_eql(subject.published)
    end

    it 'allows values comparison with string' do
      value = subject.draft
      expect(value).to be > 'created'
      expect(value).to be < 'archived'
      expect(value).to_not be_eql('published')
    end

    it 'allows values comparison with number' do
      value = subject.draft
      expect(value).to be > 0
      expect(value).to be < 3
      expect(value).to_not be_eql(2.5)
    end

    it 'does not allow cross-enum comparison' do
      expect { subject.draft == mock_enum.draft }.to raise_error(error, /^Comparison/)
      expect { subject.draft < mock_enum.published }.to raise_error(error, /^Comparison/)
      expect { subject.draft > mock_enum.created }.to raise_error(error, /^Comparison/)
    end

    it 'does not allow other types comparison' do
      expect { subject.draft > true }.to raise_error(error, /^Comparison/)
      expect { subject.draft < [] }.to raise_error(error, /^Comparison/)
    end

    it 'accepts value checking' do
      value = subject.draft
      expect(value).to respond_to(:archived?)
      expect(value.draft?).to be_truthy
      expect(value.published?).to be_falsey
    end

    it 'accepts replace and bang value' do
      value = subject.draft
      expect(value).to respond_to(:archived!)
      expect(value.archived!).to be_eql(subject.archived)
      expect(value.replace('created')).to be_eql(subject.created)
    end

    it 'accepts values turn into integer by its index' do
      mock_value = mock_enum.new('15')
      expect(subject.created.to_i).to be_eql(0)
      expect(subject.archived.to_i).to be_eql(3)
      expect(mock_value.to_i).to_not be_eql(15)
      expect(mock_value.to_i).to be_eql(4)
    end
  end

  context 'on OID' do
    let(:enum) { Enum::ContentStatus }
    subject { Torque::PostgreSQL::Adapter::OID::Enum.new('content_status') }

    context 'on deserialize' do
      it 'returns nil' do
        expect(subject.deserialize(nil)).to be_nil
      end

      it 'returns enum' do
        value = subject.deserialize('created')
        expect(value).to be_a(enum)
        expect(value).to be_eql(enum.created)
      end
    end

    context 'on serialize' do
      it 'returns nil' do
        expect(subject.serialize(nil)).to be_nil
        expect(subject.serialize('test')).to be_nil
        expect(subject.serialize(15)).to be_nil
      end

      it 'returns as string' do
        expect(subject.serialize(enum.created)).to be_eql('created')
        expect(subject.serialize(1)).to be_eql('draft')
      end
    end

    context 'on cast' do
      it 'accepts nil' do
        expect(subject.cast(nil)).to be_nil
      end

      it 'accepts invalid values as nil' do
        expect(subject.cast(false)).to be_nil
        expect(subject.cast(true)).to be_nil
        expect(subject.cast([])).to be_nil
      end

      it 'accepts string' do
        value = subject.cast('created')
        expect(value).to be_eql(enum.created)
        expect(value).to be_a(enum)
      end

      it 'accepts numeric' do
        value = subject.cast(1)
        expect(value).to be_eql(enum.draft)
        expect(value).to be_a(enum)
      end
    end
  end
end