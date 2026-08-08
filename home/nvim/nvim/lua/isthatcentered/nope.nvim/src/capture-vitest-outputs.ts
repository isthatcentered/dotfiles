#!/usr/bin/env node

/**
 * Capture Vitest Test Outputs Script
 * 
 * This script runs Vitest tests and captures all test events as individual JSON files.
 * Each event emitted by Vitest during the test run is saved to a separate numbered file.
 * 
 * Usage:
 *   node scripts/capture-vitest-outputs.js --dir <test-dir> --config <config-path> [--output <output-dir>]
 *   OR
 *   npx tsx scripts/capture-vitest-outputs.ts --dir <test-dir> --config <config-path> [--output <output-dir>]
 * 
 * Parameters:
 *   --dir <path>       Directory or file pattern to test (required)
 *   --config <path>    Path to Vitest config file (required)
 *   --output <path>    Output directory (optional, defaults to ./vitest_test_run_output)
 * 
 * Examples:
 *   npx tsx scripts/capture-vitest-outputs.ts --dir src/modules/admin --config config/vitest.unit.config.ts
 *   npx tsx scripts/capture-vitest-outputs.ts --dir src/lib/batch --config config/vitest.unit.config.ts --output ./my-output
 * 
 * Output:
 *   Creates a timestamped directory containing:
 *   - Numbered JSON files for each test event (0001_onInit.json, 0002_onTestRunStart.json, etc.)
 *   - manifest.json with summary information
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

interface ScriptArgs {
  dir: string;
  config: string;
  output?: string;
}

function parseArgs(): ScriptArgs {
  const args = process.argv.slice(2);
  const parsed: Partial<ScriptArgs> = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    if (arg === '--dir' && args[i + 1]) {
      parsed.dir = args[i + 1];
      i++;
    } else if (arg === '--config' && args[i + 1]) {
      parsed.config = args[i + 1];
      i++;
    } else if (arg === '--output' && args[i + 1]) {
      parsed.output = args[i + 1];
      i++;
    }
  }

  // Validate required arguments
  if (!parsed.dir) {
    console.error('Error: --dir parameter is required');
    printUsage();
    process.exit(1);
  }

  if (!parsed.config) {
    console.error('Error: --config parameter is required');
    printUsage();
    process.exit(1);
  }

  return parsed as ScriptArgs;
}

function printUsage(): void {
  console.log(`
Usage:
  tsx scripts/capture-vitest-outputs.ts --dir <test-dir> --config <config-path> [--output <output-dir>]

Parameters:
  --dir <path>       Directory or file pattern to test (required)
  --config <path>    Path to Vitest config file (required)
  --output <path>    Output directory (optional, defaults to ./vitest_test_run_output)

Examples:
  tsx scripts/capture-vitest-outputs.ts --dir src/modules/admin --config config/vitest.unit.config.ts
  tsx scripts/capture-vitest-outputs.ts --dir src/lib/batch --config config/vitest.unit.config.ts --output ./my-output
`);
}

function createOutputDirectory(baseDir: string): string {
  const timestamp = new Date()
    .toISOString()
    .replace(/:/g, '-')
    .replace(/\..+/, '')
    .replace(/T/, '_');
  
  const outputDir = path.join(baseDir, `run_${timestamp}`);
  
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  return outputDir;
}

function resolveConfigPath(configPath: string): string {
  // Try to resolve relative to current working directory
  const cwdPath = path.resolve(process.cwd(), configPath);
  if (fs.existsSync(cwdPath)) {
    return cwdPath;
  }

  // Try to resolve as absolute path
  if (fs.existsSync(configPath)) {
    return configPath;
  }

  console.error(`Error: Config file not found at ${configPath}`);
  console.error(`Tried: ${cwdPath}`);
  process.exit(1);
}

function resolveDirPath(dirPath: string): string {
  // Try to resolve relative to current working directory
  const cwdPath = path.resolve(process.cwd(), dirPath);
  if (fs.existsSync(cwdPath)) {
    return cwdPath;
  }

  // Try to resolve as absolute path
  if (fs.existsSync(dirPath)) {
    return dirPath;
  }

  console.warn(`Warning: Directory not found at ${dirPath}`);
  console.warn(`Tried: ${cwdPath}`);
  console.warn(`Proceeding anyway - Vitest will handle pattern matching...`);
  
  return dirPath;
}

function main(): void {
  const args = parseArgs();

  // Resolve paths
  const configPath = resolveConfigPath(args.config);
  const dirPath = resolveDirPath(args.dir);
  const baseOutputDir = args.output || './vitest_test_run_output';
  const outputDir = createOutputDirectory(baseOutputDir);

  console.log('='.repeat(80));
  console.log('Vitest Event Capture Script');
  console.log('='.repeat(80));
  console.log(`Test directory:   ${dirPath}`);
  console.log(`Config file:      ${configPath}`);
  console.log(`Output directory: ${outputDir}`);
  console.log('='.repeat(80));
  console.log('');

  // Create a temporary config file that includes our reporter
  const tempConfigPath = createTempConfig(configPath, outputDir);

  try {
    // Run Vitest using the CLI with the temporary config
    const vitestCmd = `npx vitest run --config ${tempConfigPath} ${dirPath}`;
    
    console.log(`Running: ${vitestCmd}\n`);
    
    execSync(vitestCmd, {
      stdio: 'inherit',
      cwd: process.cwd(),
    });

    console.log('');
    console.log('='.repeat(80));
    console.log('Test run completed!');
    console.log(`Events captured in: ${outputDir}`);
    console.log('='.repeat(80));

    // Read and display manifest
    const manifestPath = path.join(outputDir, 'manifest.json');
    if (fs.existsSync(manifestPath)) {
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
      console.log('');
      console.log('Summary:');
      console.log(`  Total events captured: ${manifest.totalEvents}`);
      console.log(`  Total tests: ${manifest.summary.totalTests}`);
      console.log(`  Passed: ${manifest.summary.passed}`);
      console.log(`  Failed: ${manifest.summary.failed}`);
      console.log(`  Skipped: ${manifest.summary.skipped}`);
      console.log('');
    }

  } catch (error: any) {
    console.error('Error running tests:', error.message);
    process.exit(error.status || 1);
  } finally {
    // Clean up temporary config
    if (fs.existsSync(tempConfigPath)) {
      fs.unlinkSync(tempConfigPath);
    }
  }
}

function createTempConfig(originalConfigPath: string, outputDir: string): string {
  const tempConfigPath = path.join(process.cwd(), '.vitest.capture.config.ts');
  
  const reporterPath = path.resolve(__dirname, 'vitest-event-capture-reporter.ts');
  
  // Escape backslashes in Windows paths
  const escapedOutputDir = outputDir.replace(/\\/g, '\\\\');
  const escapedReporterPath = reporterPath.replace(/\\/g, '\\\\');
  const escapedOriginalConfigPath = originalConfigPath.replace(/\\/g, '\\\\');
  
  const configContent = `
import { defineConfig, mergeConfig } from 'vitest/config';
import originalConfig from '${escapedOriginalConfigPath}';
import { VitestEventCaptureReporter } from '${escapedReporterPath}';

export default defineConfig((configEnv) => {
  const baseConfig = typeof originalConfig === 'function' 
    ? originalConfig(configEnv) 
    : originalConfig;
    
  return mergeConfig(
    baseConfig,
    defineConfig({
      test: {
        reporters: [
          'default',
          new VitestEventCaptureReporter({ outputDir: '${escapedOutputDir}' })
        ],
      },
    })
  );
});
`;

  fs.writeFileSync(tempConfigPath, configContent, 'utf-8');
  return tempConfigPath;
}

// Run the script
try {
  main();
} catch (error) {
  console.error('Fatal error:', error);
  process.exit(1);
}
