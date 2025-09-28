vim9script

# v:colornames populated by using the :colorscheme or :highlight commands,
# so can be empty if vim loaded from a session without setting a colorscheme
if empty(v:colornames) && filereadable($VIMRUNTIME .. '/colors/lists/default.vim')
    exe "source " .. $VIMRUNTIME .. '/colors/lists/default.vim'
endif

# Color table stored outside of devicons script to allow it to be modified
# before loading devicons, which creates highlight groups using these colors
# These are just the default devicon colors, a small subset of all available
# devicons chosen based on the Stack Overflow Developer Survey and TIOBE Index
# over time, and a very biased view on which are most relevant for Vim users
# You can modify this for your preferences using g:fuzzbox_devicons_color_table
# Please open a PR if you think something is missing or could be improved (all
# defaults should have an icon in vim-devicons, and a published nerdfont glyph)
var devicons_color_table = {
    '__default__': 'lightblue4',
    '*.c': 'lightblue3',
    '*.conf': 'grey', # generic settings devicon, also used for toml, yaml etc.
    '*.cpp': 'lightblue4',
    '*.cs': 'slateblue2',
    '*.css': 'lightblue3',
    '*.dart': 'lightblue4',
    '*.go': 'lightblue3',
    '*.html': 'sandybrown',
    '*.java': 'chocolate2', # similar to nvim-web-devicons, kinda coffee colored
    '*.js': 'goldenrod',
    '*.json': 'indianred',
    '*.jsx': 'teal',
    '*.lua': 'slateblue',
    '*.md': 'sandybrown',
    '*.php': 'mediumpurple',
    '*.png': 'mediumpurple', # generic image devicon, also used for gif, jpg etc.
    '*.py': 'goldenrod',
    '*.r': 'lightblue3',
    '*.rb': 'red4',
    '*.rs': 'chocolate3',
    '*.scss': 'lightblue3',
    '*.sh': 'darkorchid', # blame O'Reilly books, and UNIX sysadmin 'purple book'
    '*.sql': 'teal',
    '*.swift': 'darkorange2',
    '*.tex': 'teal',
    '*.ts': 'lightblue4',
    '*.vim': 'darkseagreen',
    'Dockerfile': 'steelblue',
    'LICENSE': 'mediumorchid',
    'vimrc': 'darkseagreen', # vim-nerdfont uses different glyphs for *.vim and vimrc
}
# Additional color table for nerdfonts not supported by default in vim-devicons
# These are added to the default color table if supported by the glyph function
var additional_color_table = {
    '*.kt': 'mediumpurple'
}
if exists('g:fuzzbox_devicons_glyph_func')
    var glyph_func = g:fuzzbox_devicons_glyph_func
    var default_glyph = function(glyph_func)('__default__')
    filter(additional_color_table, (key, val) => {
        return function(glyph_func)(key) != default_glyph
    })
    extend(devicons_color_table, additional_color_table)
endif
if exists('g:fuzzbox_devicons_color_table') && type(g:fuzzbox_devicons_color_table) == v:t_dict
    extend(devicons_color_table, g:fuzzbox_devicons_color_table)
endif

# Necessary for some versions of Vim 9.0
export def DeviconsColorTable(): dict<any>
    return devicons_color_table
enddef

# Code to get a 256 color number from a color name or hex value in the
# color table, used by devicons script when creating highlight groups
#
# Copied from https://github.com/tiagofumo/vim-nerdtree-syntax-highlight,
# which copied from https://github.com/chriskempson/vim-tomorrow-theme.
# Exports one function, to get a terminal color number from a color name
#
# Removed support for fewer than 256 colors, and updated for vim9script
# Also updated to use American rather than British English (I personally
# write in British English, but Fuzzbox generally uses American English)

# Returns an approximate gray index for the given gray level
def GrayNumber(x: number): number
    if x < 14
        return 0
    else
        var n = (x - 8) / 10
        var m = (x - 8) % 10
        if m < 5
            return n
        else
            return n + 1
        endif
    endif
enddef

# Returns the actual gray level represented by the gray index
def GrayLevel(n: number): number
    if n == 0
        return 0
    else
        return 8 + (n * 10)
    endif
enddef

# Returns the palette index for the given gray index
def GrayColor(n: number): number
    if n == 0
        return 16
    elseif n == 25
        return 231
    else
        return 231 + n
    endif
enddef

# Returns an approximate color index for the given color level
def RgbNumber(x: number): number
    if x < 75
        return 0
    else
        var n = (x - 55) / 40
        var m = (x - 55) % 40
        if m < 20
            return n
        else
            return n + 1
        endif
    endif
enddef

# Returns the actual color level for the given color index
def RgbLevel(n: number): number
    if n == 0
        return 0
    else
        return 55 + (n * 40)
    endif
enddef

# Returns the palette index for the given R/G/B color indices
def RgbColor(x: number, y: number, z: number): number
    return 16 + (x * 36) + (y * 6) + z
enddef

# Returns the palette index to approximate the given R/G/B color levels
def Rgb(r: number, g: number, b: number): number
  # Get the closest gray
  var gx = GrayNumber(r)
  var gy = GrayNumber(g)
  var gz = GrayNumber(b)

  # Get the closest color
  var x = RgbNumber(r)
  var y = RgbNumber(g)
  var z = RgbNumber(b)

  if gx == gy && gy == gz
    # There are two possibilities
    var dgr = GrayLevel(gx) - r
    var dgg = GrayLevel(gy) - g
    var dgb = GrayLevel(gz) - b
    var dgray = (dgr * dgr) + (dgg * dgg) + (dgb * dgb)
    var dr = RgbLevel(gx) - r
    var dg = RgbLevel(gy) - g
    var db = RgbLevel(gz) - b
    var drgb = (dr * dr) + (dg * dg) + (db * db)
    if dgray < drgb
      # Use the gray
      return GrayColor(gx)
    else
      # Use the color
      return RgbColor(x, y, z)
    endif
  else
    # Only one possibility
    return RgbColor(x, y, z)
  endif
enddef

# Returns the palette index to approximate the '#rrggbb' hex string
export def Hex(hex: string): number
    var r = str2nr(strpart(hex, 1, 2), 16)
    var g = str2nr(strpart(hex, 3, 2), 16)
    var b = str2nr(strpart(hex, 5, 2), 16)
    return Rgb(r, g, b)
enddef

# Returns approximate cterm color number from color name or hex color
export def TermColor(val: string): number
    if stridx(val, '#') == 0
        return Hex(val)
    endif
    if !has_key(v:colornames, val)
        echoerr "color name '" .. val .. "' not found"
    endif
    return Hex(get(v:colornames, val))
enddef

# for name in uniq(keys(v:colornames))
#     if index([202, 203, 204, 205, 206], TermColor(name)) != -1
#         echo name .. ': ' .. TermColor(name)
#     endif
#     if name =~ '^\w\+$'
#         exe 'hi fuzzboxDeviconNew_' .. name .. ' ctermfg=' .. TermColor(name) .. ' guifg=' .. name
#     endif
# endfor
