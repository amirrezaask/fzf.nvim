local Fuzzy = require('fuzzy')
local helpers = require('fuzzy.helpers')
local source = require('fuzzy.source')
local sorter = require('fuzzy.sorter')
local drawer = require('fuzzy.drawer')
local file_finder = require'fuzzy.file_finder'
local grep = require'fuzzy.grep'
local terminal_fuzzy = require'fuzzy.terminal'

-- Register execute commands
vim.cmd [[ command! Files lua require('fuzzy.internal').file_finder{} ]]
vim.cmd [[ command! Grep lua require('fuzzy.internal').grep{} ]]
vim.cmd [[ command! Find lua require('fuzzy.internal').find{} ]]
vim.cmd [[ command! Fd lua require('fuzzy.internal').fd{} ]]
vim.cmd [[ command! GFiles lua require('fuzzy.internal').git_files{} ]]
vim.cmd [[ command! GGrep lua require('fuzzy.internal').git_grep{} ]]
vim.cmd [[ command! BLines lua require('fuzzy.internal').buffer_lines{} ]]
vim.cmd [[ command! Buffers lua require('fuzzy.internal').buffers{} ]]
vim.cmd [[ command! Rg lua require('fuzzy.internal').rg{} ]]
vim.cmd [[ command! Colors lua require('fuzzy.internal').colors{} ]]
vim.cmd [[ command! Cd lua require('fuzzy.internal').cd{} ]]
vim.cmd [[ command! LspReferences lua require('fuzzy.internal').lsp_references{} ]]
vim.cmd [[ command! LspDocumentSymbols lua require('fuzzy.internal').lsp_document_symbols{} ]]
vim.cmd [[ command! LspWorkspaceSymbols lua require('fuzzy.internal').lsp_workspace_symbols{} ]]

FUZZY_DEFAULT_SORTER = sorter.Levenshtein 
local function use_default()
  if vim.g.fuzzy_use_fzf then
    return false 
  else
    return true
  end
end


return {
  grep = function(opts)
    opts = opts or {}
    opts.cwd = '.'
    opts.hidden = opts.hidden or false
    local source_and_sorter = function()
      local files = file_finder.find({
        path = opts.cwd,
        depth = opts.depth,
        hidden = opts.hidden
      })
      local lines = grep.grep(files, CURRENT_FUZZY.input or '')
      return lines
    end
    Fuzzy.new {
      source = source_and_sorter,
      sorter = source_and_sorter,
      drawer = drawer.new(),
      handler = function(line)
        local filename = vim.split(line, ':')[1]
        local linum = vim.split(line, ':')[2]
        CURRENT_FUZZY.__grep_cache= {}
        helpers.open_file_at(filename, linum)
      end
    }
  end,
  file_finder = function(opts)
    opts = opts or {}
    opts.cwd = '.'
    opts.hidden = opts.hidden or false
    Fuzzy.new {
      source = function()
        return file_finder.find({
        path = opts.cwd,
        depth = opts.depth,
        hidden = opts.hidden
      })
      end,
      sorter = FUZZY_DEFAULT_SORTER,
      drawer = drawer.new(),
      handler = function(line)
        helpers.open_file(line)
      end,
    }
  end,
  fd = function(opts)
    opts = opts or {}
    opts.cwd = '.'
    opts.hidden = opts.hidden or false
    if opts.hidden then
      opts.hidden = '--hidden'
    else
      opts.hidden = ''
    end
    local cmd = string.format('fdfind %s %s', opts.cwd, opts.hidden)
    Fuzzy.new {
      source = source.NewBinSource(cmd),
      sorter = FUZZY_DEFAULT_SORTER,
      drawer = drawer.new(),
      handler = function(line)
        helpers.open_file(line)
      end,
    }
  end,
  find = function(opts)
    opts = opts or {}
    opts.cwd = opts.cwd or '.'
    opts.hidden = opts.hidden or false
    opts.args = opts.args or {}
    table.insert(opts.args, opts.cwd)
    if not opts.hidden then
      table.insert(opts.args, [[-not -path '*/\.*']])
    end
    table.insert(opts.args, '-type s,f')
    local cmd = string.format('find %s', table.concat(opts.args, ' '))
    if use_default() then
      Fuzzy.new {
        source = source.NewBinSource(cmd),
        sorter = FUZZY_DEFAULT_SORTER,
        drawer = drawer.new(),
        handler = function(line)
          helpers.open_file(line)
        end,
      }
    else
      terminal_fuzzy.fzf(cmd, function(line)
        helpers.open_file(line)
      end)
    end
  end,
  git_files = function(opts)
    local collection = {}
    if use_default() then
      Fuzzy.new {
        collection = collection,
        source = source.NewBinSource('git ls-files'),
        sorter = FUZZY_DEFAULT_SORTER,
        drawer = drawer.new(),
        handler = function(line)
          helpers.open_file(line)
        end,
      }
    else
      terminal_fuzzy.fzf('git ls-files', function(line)
        helpers.open_file(line)
      end)
    end
  end,
  git_grep = function(opts)
    local collection = {}
    local cmd = 'git grep -n ""'
    if use_default() then
      Fuzzy.new {
        collection = collection,
        source = source.NewBinSource(cmd),
        sorter = sorter.FZF,
        drawer = drawer.new(),
        handler = function(line)
          local filename = vim.split(line, ':')[1]
          local linum = vim.split(line, ':')[2]
          helpers.open_file_at(filename, linum)
        end,
      }
    else
      terminal_fuzzy.fzf(cmd, function(line)
        local filename = vim.split(line, ':')[1]
        local linum = vim.split(line, ':')[2]
        helpers.open_file_at(filename, linum)
      end)
    end
  end,
  rg = function(opts)
    local collection = {}
    local cmd = 'rg --column --line-number --no-heading --smart-case ""'
    if use_default() then
      Fuzzy.new {
        collection = collection,
        source = source.NewBinSource(),
        sorter = function(query, _)
          return source.NewBinSource(string.format('rg --column --line-number --no-heading --smart-case "%s"', query))()
        end,
        drawer = drawer.new(),
        handler = function(line)
          local filename = vim.split(line, ':')[1]
          local linum = vim.split(line, ':')[2]
          helpers.open_file_at(filename, linum)
        end,
      }
    else
      terminal_fuzzy.fzf(cmd, function(line)
        local filename = vim.split(line, ':')[1]
        local linum = vim.split(line, ':')[2]
        helpers.open_file_at(filename, linum)
      end)
  end
  end,
  buffers = function(opts)
    local _buffers = {}
    for _,b in ipairs(vim.api.nvim_list_bufs()) do
      if 1 == vim.fn.buflisted(b) then
        table.insert(_buffers, string.format("%s: %s", b, vim.api.nvim_buf_get_name(b)))
      end
    end
    if use_default() then
      Fuzzy.new {
        sorter = FUZZY_DEFAULT_SORTER,
        drawer = drawer.new(),
        handler = function(line)
          local buffer_name = vim.split(line, ':')[2]
          vim.cmd(string.format('buffer %s', buffer_name))
        end,
        collection = _buffers,
      }
    else
      terminal_fuzzy.fzf(_buffers, function(line)
        local buffer_name = vim.split(line, ':')[2]
        vim.cmd(string.format('buffer %s', buffer_name))
      end)
    end
  end,
  buffer_lines = function(opts)
    local filename = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
    local cmd = string.format('cat --number %s', filename)
    if use_default() then
      Fuzzy.new {
        source = source.NewBinSource(cmd),
        sorter = FUZZY_DEFAULT_SORTER,
        drawer = drawer.new(),
        handler = function(line)
          local number = vim.split(line, '  ')[3]
          helpers.open_file_at(filename, number)
        end,
      }
    else
      terminal_fuzzy.fzf(cmd, 
      function(line)
        local number = vim.split(line, '  ')[3]
        helpers.open_file_at(filename, number)
      end)
    end
  end,
  cd = function(opts)
    opts = opts or {}
    opts.cwd = opts.cwd or '.'
    opts.hidden = opts.hidden or false
    opts.args = opts.args or {}
    table.insert(opts.args, opts.cwd)
    if not opts.hidden then
      table.insert(opts.args, [[-not -path '*/\.*']])
    end
    table.insert(opts.args, '-type s,d')
    local cmd = string.format('find %s', table.concat(opts.args, ' '))
    if use_default() then
      Fuzzy.new {
        source = source.NewBinSource(cmd),
        sorter = sorter.FZF,
        drawer = drawer.new(),
        handler = function(line)
          vim.cmd(string.format('cd %s', line))
        end,
      }
    else
      terminal_fuzzy.fzf(cmd, function(line)
        vim.cmd(string.format('cd %s', line))
      end)
    end
  end,
  colors = function(opts)
    if use_default() then
      Fuzzy.new {
        sorter = FUZZY_DEFAULT_SORTER,
        drawer = drawer.new(),
        handler = function(color)
          vim.cmd(string.format('colorscheme %s', color))
        end,
        collection = vim.fn.getcompletion('', 'color'),
      }
    else
      terminal_fuzzy.fzf(vim.fn.getcompletion('', 'color'), function(color)
        vim.cmd(string.format('colorscheme %s', color))
      end)
    end
  end,
  lsp_document_symbols = function(opts)
    opts = opts or {}
    local params = vim.lsp.util.make_position_params()
    params.context = { includeDeclaration = true }
    params.query = '' 
    local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 10000)
    local locations = {}
    for _, server_results in pairs(results_lsp) do
      if server_results.result then
        vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result) or {})
      end
    end
    local lines = {}
    for _, loc in ipairs(locations) do
      table.insert(lines, string.format('%s:%s:%s', loc.filename, loc.lnum, loc.text))
    end
    local cmd = table.concat(lines, '\n')
    if use_default() then
      Fuzzy.new {
        collection = lines,
        sorter = sorter.FZF,
        drawer = drawer.new(),
        handler = function(line)
          local segments = split(line, ":")
          helpers.open_file_at(segments[1], segments[2])
        end
      }
    else
      terminal_fuzzy.fzf(lines, function(line)
        local segments = split(line, ":")
        helpers.open_file_at(segments[1], segments[2])
      end)
    end
  end,
  lsp_workspace_symbols = function(opts)
    opts = opts or {}
    local params = vim.lsp.util.make_position_params()
    params.context = { includeDeclaration = true }
    params.query = ''
    local results_lsp = vim.lsp.buf_request_sync(0, "workspace/symbol", params, opts.timeout or 10000)
    local locations = {}
    for _, server_results in pairs(results_lsp) do
      if server_results.result then
        vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result) or {})
      end
    end
    local lines = {}
    for _, loc in ipairs(locations) do
      table.insert(lines, string.format('%s:%s:%s', loc.filename, loc.lnum, loc.text))
    end
    if use_default() then
      Fuzzy.new {
        collection = lines,
        handler = function(line)
          local segments = split(line, ":")
          helpers.open_file_at(segments[1], segments[2])
        end,
        sorter = sorter.FZF,
        drawer = drawer.new(),
      }
    else
      terminal_fuzzy.fzf(lines, function(line)
        local segments = split(line, ":")
        helpers.open_file_at(segments[1], segments[2])
      end)
    end
  end,
  lsp_references = function(opts)
    opts = opts or {}
    local params = vim.lsp.util.make_position_params()
    params.context = { includeDeclaration = true }
    local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/references", params, opts.timeout or 10000)
    local locations = {}
    for _, server_results in pairs(results_lsp) do
      if server_results.result then
        vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
      end
    end
    local callback = function(line)
      local segments = split(line, ":")
      helpers.open_file_at(segments[1], segments[2])
    end
    opts.callback = callback
    local lines = {}
    for _, loc in ipairs(locations) do
      table.insert(lines, string.format('%s:%s:%s', loc.filename, loc.lnum, loc.text))
    end
    if use_default() then
      Fuzzy.new {
        collection = lines,
        handler = function(line)
          local segments = split(line, ":")
          helpers.open_file_at(segments[1], segments[2])
        end,
        sorter = FUZZY_DEFAULT_SORTER,
        drawer = drawer.new(),
      }
    else
      terminal_fuzzy.fzf(lines, function(line)
        local segments = split(line, ":")
        helpers.open_file_at(segments[1], segments[2])
      end)
    end
  end
}
