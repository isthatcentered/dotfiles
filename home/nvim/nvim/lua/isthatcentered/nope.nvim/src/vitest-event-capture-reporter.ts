/* eslint-disable @typescript-eslint/no-explicit-any */
import * as fs from 'fs';
import * as path from 'path';

export interface EventCaptureReporterOptions {
  outputDir: string;
}

/**
 * Custom Vitest reporter that captures all test events as individual JSON files.
 * Each event is saved with a sequential number and event type in the filename.
 * 
 * This reporter implements the Vitest Reporter interface to capture events throughout
 * the test execution lifecycle.
 */
export default class VitestEventCaptureReporter {
  private outputDir: string;
  private eventCounter = 0;
  private ctx: any;

  constructor(options: EventCaptureReporterOptions) {
    this.outputDir = options.outputDir;
    this.ensureOutputDirectory();
  }

  private ensureOutputDirectory(): void {
    if (!fs.existsSync(this.outputDir)) {
      fs.mkdirSync(this.outputDir, { recursive: true });
    }
  }

  private getNextCounter(): number {
    return ++this.eventCounter;
  }

  private sanitizePath(filePath: string): string {
    return filePath
      .replace(/\\/g, '/')
      .replace(/^.*\/src\//, 'src-')
      .replace(/\//g, '-')
      .replace(/\.[^.]+$/, '')
      .replace(/[^a-zA-Z0-9-_]/g, '_');
  }

  private writeEvent(eventType: string, data: any, testPath?: string): void {
    const counter = this.getNextCounter();
    const counterStr = counter.toString().padStart(4, '0');
    
    let filename = `${counterStr}_${eventType}`;
    if (testPath) {
      filename += `_${this.sanitizePath(testPath)}`;
    }
    filename += '.json';

    const filePath = path.join(this.outputDir, filename);

    // Create the event payload
    const payload = {
      eventType,
      counter,
      timestamp: new Date().toISOString(),
      data: this.serializeData(data),
    };

    try {
      fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), 'utf-8');
    } catch (error) {
      console.error(`Failed to write event file ${filename}:`, error);
    }
  }

  private serializeData(data: any): any {
    // Handle circular references and non-serializable objects
    const seen = new WeakSet();
    
    return JSON.parse(JSON.stringify(data, (key, value) => {
      // Handle circular references
      if (typeof value === 'object' && value !== null) {
        if (seen.has(value)) {
          return '[Circular]';
        }
        seen.add(value);
      }

      // Handle functions
      if (typeof value === 'function') {
        return `[Function: ${value.name || 'anonymous'}]`;
      }

      // Handle symbols
      if (typeof value === 'symbol') {
        return value.toString();
      }

      // Handle BigInt
      if (typeof value === 'bigint') {
        return value.toString() + 'n';
      }

      // Handle undefined (JSON.stringify removes undefined by default)
      if (value === undefined) {
        return '[undefined]';
      }

      return value;
    }));
  }

  // Reporter lifecycle hooks

  onInit(ctx: any): void {
    this.ctx = ctx;
    this.writeEvent('onInit', {
      version: ctx?.version,
      root: ctx?.config?.root,
      mode: ctx?.config?.mode,
    });
  }

  onPathsCollected(paths?: string[]): void {
    this.writeEvent('onPathsCollected', {
      totalPaths: paths?.length || 0,
      paths: paths || [],
    });
  }

  onCollected(files?: any[]): void {
    this.writeEvent('onCollected', {
      totalFiles: files?.length || 0,
      files: files?.map((file: any) => ({
        filepath: file?.filepath,
        name: file?.name,
        type: file?.type,
        mode: file?.mode,
      })) || [],
    });
  }

  onFinished(files?: any[], errors?: any[]): void {
    const summary = this.calculateSummary(files || []);
    
    this.writeEvent('onFinished', {
      totalFiles: files?.length || 0,
      totalErrors: errors?.length || 0,
      summary,
      files: files?.map((file: any) => ({
        filepath: file?.filepath,
        tasks: file?.tasks?.length || 0,
      })) || [],
      errors: errors || [],
    });

    // Write a manifest file
    this.writeManifest(summary);
  }

  onTaskUpdate(packs: any[]): void {
    for (const pack of packs) {
      const [taskId, result] = pack;
      const task = this.findTask(taskId);
      
      if (task) {
        this.writeEvent('onTaskUpdate', {
          taskId,
          name: task.name,
          type: task.type,
          file: task.file?.filepath,
          result: result ? {
            state: result.state,
            duration: result.duration,
            errors: result.errors,
          } : null,
        }, task.file?.filepath);
      }
    }
  }

  onTestRemoved(trigger?: string): void {
    this.writeEvent('onTestRemoved', {
      trigger,
    });
  }

  onWatcherStart(files?: any[], errors?: any[]): void {
    this.writeEvent('onWatcherStart', {
      totalFiles: files?.length || 0,
      totalErrors: errors?.length || 0,
    });
  }

  onWatcherRerun(files: string[], trigger?: string): void {
    this.writeEvent('onWatcherRerun', {
      files,
      trigger,
    });
  }

  onServerRestart(reason?: string): void {
    this.writeEvent('onServerRestart', {
      reason,
    });
  }

  onProcessTimeout(): void {
    this.writeEvent('onProcessTimeout', {});
  }

  onUserConsoleLog(log: any): void {
    this.writeEvent('onUserConsoleLog', {
      type: log?.type,
      content: log?.content,
      taskId: log?.taskId,
    });
  }

  // Helper methods

  private findTask(taskId: string): any {
    if (!this.ctx?.state) return null;
    
    const files = this.ctx.state.getFiles();
    for (const file of files) {
      const task = this.findTaskRecursive(file, taskId);
      if (task) return task;
    }
    return null;
  }

  private findTaskRecursive(task: any, taskId: string): any {
    if (task.id === taskId) return task;
    
    if (task.tasks) {
      for (const child of task.tasks) {
        const found = this.findTaskRecursive(child, taskId);
        if (found) return found;
      }
    }
    
    return null;
  }

  private calculateSummary(files: any[]): any {
    const summary = {
      totalTests: 0,
      passed: 0,
      failed: 0,
      skipped: 0,
      todo: 0,
      totalDuration: 0,
    };

    for (const file of files) {
      this.collectFileStats(file, summary);
    }

    return summary;
  }

  private collectFileStats(file: any, summary: any): void {
    if (file.tasks) {
      for (const task of file.tasks) {
        this.collectTaskStats(task, summary);
      }
    }
  }

  private collectTaskStats(task: any, summary: any): void {
    if (task.type === 'test') {
      summary.totalTests++;
      
      if (task.result) {
        const state = task.result.state;
        if (state === 'pass') {
          summary.passed++;
        } else if (state === 'fail') {
          summary.failed++;
        } else if (state === 'skip') {
          summary.skipped++;
        } else if (state === 'todo') {
          summary.todo++;
        }

        if (task.result.duration !== undefined) {
          summary.totalDuration += task.result.duration;
        }
      }
    } else if (task.tasks) {
      for (const child of task.tasks) {
        this.collectTaskStats(child, summary);
      }
    }
  }

  private writeManifest(summary: any): void {
    const manifest = {
      totalEvents: this.eventCounter,
      runTimestamp: new Date().toISOString(),
      summary,
      outputDirectory: this.outputDir,
    };

    const manifestPath = path.join(this.outputDir, 'manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), 'utf-8');
  }
}
