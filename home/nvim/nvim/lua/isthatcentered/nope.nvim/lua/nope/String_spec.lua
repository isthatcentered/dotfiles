local String = require('nope.String')

describe('String', function()
  describe('pad_end', function()
    it('pads with spaces by default', function()
      assert.same('foo   ', String.pad_end('foo', 6))
    end)

    it('pads with custom char', function()
      assert.same('foo000', String.pad_end('foo', 6, '0'))
    end)

    it('returns original if already at target length', function()
      assert.same('foobar', String.pad_end('foobar', 6))
    end)

    it('returns original if exceeding target length', function()
      assert.same('foobar', String.pad_end('foobar', 3))
    end)

    it('pads empty string', function()
      assert.same('   ', String.pad_end('', 3))
    end)
  end)

  describe('pad_start', function()
    it('pads with spaces by default', function()
      assert.same('   foo', String.pad_start('foo', 6))
    end)

    it('pads with custom char', function()
      assert.same('000foo', String.pad_start('foo', 6, '0'))
    end)

    it('returns original if already at target length', function()
      assert.same('foobar', String.pad_start('foobar', 6))
    end)

    it('returns original if exceeding target length', function()
      assert.same('foobar', String.pad_start('foobar', 3))
    end)

    it('pads empty string', function()
      assert.same('   ', String.pad_start('', 3))
    end)
  end)

  describe('split', function()
    it('splits string into chunks of specified length', function()
      assert.same({ 'he', 'll', 'o' }, String.split('hello', 2))
    end)

    it('returns single element when string shorter than length', function()
      assert.same({ 'hi' }, String.split('hi', 5))
    end)

    it('handles exact multiples of length', function()
      assert.same({ 'ab', 'cd' }, String.split('abcd', 2))
    end)

    it('returns empty table for empty string', function()
      assert.same({}, String.split('', 3))
    end)

    it('handles length of 1', function()
      assert.same({ 'a', 'b', 'c' }, String.split('abc', 1))
    end)
  end)

  describe('trim', function()
    it('removes leading spaces', function()
      assert.same('foo', String.trim('   foo'))
    end)

    it('removes trailing spaces', function()
      assert.same('foo', String.trim('foo   '))
    end)

    it('removes both leading and trailing spaces', function()
      assert.same('foo', String.trim('   foo   '))
    end)

    it('handles empty string', function()
      assert.same('', String.trim(''))
    end)

    it('returns string unchanged if no whitespace', function()
      assert.same('foo', String.trim('foo'))
    end)

    it('handles tabs and newlines', function()
      assert.same('foo', String.trim('\t\n foo \t\n'))
    end)

    it('preserves internal whitespace', function()
      assert.same('foo bar', String.trim('  foo bar  '))
    end)
  end)

  describe('crop', function()
    it('crops string to specified length', function()
      assert.same('foo', String.crop('foobar', 3))
    end)

    it('returns original if shorter than length', function()
      assert.same('foo', String.crop('foo', 6))
    end)

    it('returns original if equal to length', function()
      assert.same('foobar', String.crop('foobar', 6))
    end)

    it('handles empty string', function()
      assert.same('', String.crop('', 3))
    end)

    it('handles length of 0', function()
      assert.same('', String.crop('foo', 0))
    end)
  end)
end)
