vim9script

const NerdFontBuiltinRules: list<dict<any>> = [
  {text: '󰡨 ', color: '#2496ED', when: {is_dir: false, name_pattern: '^\.dockerignore$'}},
  {text: ' ', color: '#019833', when: {is_dir: false, name_pattern: '^\.vimrc$'}},
  {text: '󰡨 ', color: '#2496ED', when: {is_dir: false, name_pattern: '^Dockerfile$'}},
  {text: ' ', color: '#427819', when: {is_dir: false, name_pattern: '\v^(Makefile|GNUmakefile)$'}},
  {text: ' ', color: '#89E051', when: {is_dir: false, name_pattern: glob2regpat('*.bash')}},
  {text: ' ', color: '#599EFF', when: {is_dir: false, name_pattern: glob2regpat('*.c')}},
  {text: ' ', color: '#6D8086', when: {is_dir: false, name_pattern: glob2regpat('*.conf')}},
  {text: ' ', color: '#F34B7D', when: {is_dir: false, name_pattern: glob2regpat('*.cpp')}},
  {text: ' ', color: '#1572B6', when: {is_dir: false, name_pattern: glob2regpat('*.css')}},
  {text: ' ', color: '#EBCB8B', when: {is_dir: false, name_pattern: glob2regpat('*.diff')}},
  {text: ' ', color: '#00ADD8', when: {is_dir: false, name_pattern: glob2regpat('*.go')}},
  {text: ' ', color: '#A8B9CC', when: {is_dir: false, name_pattern: glob2regpat('*.h')}},
  {text: ' ', color: '#A8B9CC', when: {is_dir: false, name_pattern: glob2regpat('*.hpp')}},
  {text: ' ', color: '#E34C26', when: {is_dir: false, name_pattern: glob2regpat('*.html')}},
  {text: ' ', color: '#F1E05A', when: {is_dir: false, name_pattern: glob2regpat('*.js')}},
  {text: ' ', color: '#CBCB41', when: {is_dir: false, name_pattern: glob2regpat('*.json')}},
  {text: ' ', color: '#61DAFB', when: {is_dir: false, name_pattern: glob2regpat('*.jsx')}},
  {text: ' ', color: '#BBBBBB', when: {is_dir: false, name_pattern: glob2regpat('*.lock')}},
  {text: ' ', color: '#51A0CF', when: {is_dir: false, name_pattern: glob2regpat('*.lua')}},
  {text: '󰍔 ', color: '#519ABA', when: {is_dir: false, name_pattern: glob2regpat('*.md')}},
  {text: ' ', color: '#3572A5', when: {is_dir: false, name_pattern: glob2regpat('*.py')}},
  {text: ' ', color: '#DEA584', when: {is_dir: false, name_pattern: glob2regpat('*.rs')}},
  {text: ' ', color: '#89E051', when: {is_dir: false, name_pattern: glob2regpat('*.sh')}},
  {text: ' ', color: '#9C4221', when: {is_dir: false, name_pattern: glob2regpat('*.toml')}},
  {text: ' ', color: '#3178C6', when: {is_dir: false, name_pattern: glob2regpat('*.ts')}},
  {text: ' ', color: '#3178C6', when: {is_dir: false, name_pattern: glob2regpat('*.tsx')}},
  {text: '󰈙 ', color: '#A6ACCD', when: {is_dir: false, name_pattern: glob2regpat('*.txt')}},
  {text: ' ', color: '#019833', when: {is_dir: false, name_pattern: glob2regpat('*.vim')}},
  {text: '󰗀 ', color: '#E37933', when: {is_dir: false, name_pattern: glob2regpat('*.xml')}},
  {text: ' ', color: '#CB171E', when: {is_dir: false, name_pattern: glob2regpat('*.yaml')}},
  {text: ' ', color: '#CB171E', when: {is_dir: false, name_pattern: glob2regpat('*.yml')}},
  {text: ' ', color: '#E0AF68', when: {is_dir: false, name_pattern: glob2regpat('*.zip')}},
]

const NerdFontTypeFallbacks: dict<dict<string>> = {
  directory: {text: ' ', color: '#7EB7E6'},
  symlink: {text: ' ', color: '#D08770'},
  executable: {text: ' ', color: '#89E051'},
  file: {text: ' ', color: '#C0C0C0'},
}

const EmptyIcon: dict<string> = {text: '', color: '', kind: ''}
const BoolConditionKeys: list<string> = ['is_dir', 'is_symlink', 'is_executable']

export def Resolve(entry: dict<any>): dict<string>
  if !IconsEnabled()
    return EmptyIcon
  endif

  var facts = EntryFacts(entry)
  var user_rules = get(g:, 'v9filer_nerd_font_icon_rules', [])
  var rule = MatchingIconRule(facts, user_rules)
  if empty(rule)
    rule = MatchingIconRule(facts, NerdFontBuiltinRules)
  endif

  if !empty(rule)
    return IconSpec(RuleText(rule), RuleColor(rule), facts.kind)
  endif

  var fallback = NerdFontTypeFallbacks[facts.kind]
  return IconSpec(fallback.text, fallback.color, facts.kind)
enddef

export def IsIconColor(color: string): bool
  return color =~# '^#[0-9A-Fa-f]\{6}$'
enddef

export def IconsEnabled(): bool
  var config: any = get(g:, 'v9filer_nerd_font_icons', false)
  if type(config) == v:t_bool || type(config) == v:t_number
    return config ? true : false
  endif
  return false
enddef

def MatchingIconRule(facts: dict<any>, rules: list<any>): dict<any>
  for rule in rules
    if type(rule) == v:t_dict
        && RuleHasText(rule)
        && RuleMatches(facts, get(rule, 'when', {}))
      return rule
    endif
  endfor
  return {}
enddef

def IconSpec(text: string, color: string, kind: string): dict<string>
  return {text: text, color: color, kind: kind}
enddef

def RuleText(rule: dict<any>): string
  var text: any = get(rule, 'text', '')
  return type(text) == v:t_string ? text : ''
enddef

def RuleColor(rule: dict<any>): string
  var color: any = get(rule, 'color', '')
  return type(color) == v:t_string ? color : ''
enddef

def RuleHasText(rule: dict<any>): bool
  return type(get(rule, 'text', '')) == v:t_string
enddef

def EntryFacts(entry: dict<any>): dict<any>
  var name = get(entry, 'name', '')
  return {
    name: name,
    kind: EntryKind(entry),
    is_dir: get(entry, 'is_dir', false) ? true : false,
    is_symlink: get(entry, 'is_symlink', false) ? true : false,
    is_executable: get(entry, 'is_executable', false) ? true : false,
  }
enddef

def RuleMatches(facts: dict<any>, when: any): bool
  if type(when) != v:t_dict
    return false
  endif

  var conditions: dict<any> = when
  for [key, expected] in items(conditions)
    if !RuleConditionMatches(facts, key, expected)
      return false
    endif
  endfor
  return true
enddef

def RuleConditionMatches(facts: dict<any>, key: string, expected: any): bool
  if key ==# 'name_pattern'
    return type(expected) == v:t_string
      && StringMatchesPattern(facts.name, expected)
  endif

  if index(BoolConditionKeys, key) >= 0
    return BoolFactMatches(get(facts, key, false), expected)
  endif

  return false
enddef

def BoolFactMatches(actual: bool, expected: any): bool
  if type(expected) != v:t_bool && type(expected) != v:t_number
    return false
  endif
  return actual == (expected ? true : false)
enddef

def StringMatchesPattern(value: string, pattern: string): bool
  try
    return value =~# pattern
  catch
    return false
  endtry
enddef

def EntryKind(entry: dict<any>): string
  if entry.is_dir
    return 'directory'
  endif
  if get(entry, 'is_symlink', false)
    return 'symlink'
  endif
  if get(entry, 'is_executable', false)
    return 'executable'
  endif
  return 'file'
enddef
