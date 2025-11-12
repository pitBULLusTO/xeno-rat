#!/usr/bin/env python3
"""
Recursive Find and Replace Tool
Searches for a keyword in all files within a directory and replaces it.
"""

import os
import sys
import argparse
import shutil
from pathlib import Path
from typing import List, Set


class FindAndReplace:
    def __init__(
        self,
        search_text: str,
        replace_text: str,
        directory: str,
        file_extensions: List[str] = None,
        exclude_dirs: Set[str] = None,
        case_sensitive: bool = True,
        create_backup: bool = True,
        dry_run: bool = False
    ):
        """
        Initialize the Find and Replace tool.
        
        Args:
            search_text: Text to search for
            replace_text: Text to replace with
            directory: Root directory to search
            file_extensions: List of file extensions to process (e.g., ['.py', '.txt'])
            exclude_dirs: Set of directory names to skip
            case_sensitive: Whether search should be case-sensitive
            create_backup: Create .bak backup files before modifying
            dry_run: If True, only show what would be changed without modifying files
        """
        self.search_text = search_text
        self.replace_text = replace_text
        self.directory = Path(directory).resolve()
        self.file_extensions = file_extensions or []
        self.exclude_dirs = exclude_dirs or {'.git', '__pycache__', 'node_modules', '.venv', 'venv'}
        self.case_sensitive = case_sensitive
        self.create_backup = create_backup
        self.dry_run = dry_run
        
        # Statistics
        self.files_scanned = 0
        self.files_modified = 0
        self.total_replacements = 0
        
    def should_process_file(self, file_path: Path) -> bool:
        """Check if file should be processed based on extension filter."""
        if not self.file_extensions:
            return True
        return file_path.suffix.lower() in [ext.lower() for ext in self.file_extensions]
    
    def should_skip_directory(self, dir_name: str) -> bool:
        """Check if directory should be skipped."""
        return dir_name in self.exclude_dirs
    
    def process_file(self, file_path: Path) -> int:
        """
        Process a single file, replacing text occurrences.
        
        Returns:
            Number of replacements made in the file
        """
        try:
            # Try to read file as text
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except (UnicodeDecodeError, PermissionError) as e:
            print(f"  ⚠️  Skipping {file_path}: {e}")
            return 0
        
        # Count occurrences
        if self.case_sensitive:
            count = content.count(self.search_text)
        else:
            count = content.lower().count(self.search_text.lower())
        
        if count == 0:
            return 0
        
        # Perform replacement
        if self.case_sensitive:
            new_content = content.replace(self.search_text, self.replace_text)
        else:
            # Case-insensitive replacement (preserves original case when possible)
            import re
            pattern = re.compile(re.escape(self.search_text), re.IGNORECASE)
            new_content = pattern.sub(self.replace_text, content)
        
        if self.dry_run:
            print(f"  🔍 Would replace {count} occurrence(s) in: {file_path}")
        else:
            # Create backup if requested
            if self.create_backup:
                backup_path = file_path.with_suffix(file_path.suffix + '.bak')
                shutil.copy2(file_path, backup_path)
            
            # Write modified content
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            print(f"  ✅ Replaced {count} occurrence(s) in: {file_path}")
        
        return count
    
    def walk_directory(self) -> None:
        """Recursively walk through directory and process files."""
        print(f"\n{'='*70}")
        print(f"Search Directory: {self.directory}")
        print(f"Search Text:      '{self.search_text}'")
        print(f"Replace With:     '{self.replace_text}'")
        print(f"Case Sensitive:   {self.case_sensitive}")
        print(f"File Extensions:  {self.file_extensions if self.file_extensions else 'All files'}")
        print(f"Exclude Dirs:     {', '.join(self.exclude_dirs)}")
        print(f"Backup Files:     {self.create_backup}")
        print(f"Dry Run:          {self.dry_run}")
        print(f"{'='*70}\n")
        
        if not self.directory.exists():
            print(f"❌ Error: Directory '{self.directory}' does not exist!")
            return
        
        # Walk through directory tree
        for root, dirs, files in os.walk(self.directory):
            root_path = Path(root)
            
            # Filter out excluded directories
            dirs[:] = [d for d in dirs if not self.should_skip_directory(d)]
            
            # Process files
            for file_name in files:
                file_path = root_path / file_name
                
                if not self.should_process_file(file_path):
                    continue
                
                self.files_scanned += 1
                replacements = self.process_file(file_path)
                
                if replacements > 0:
                    self.files_modified += 1
                    self.total_replacements += replacements
    
    def print_summary(self) -> None:
        """Print summary of operations."""
        print(f"\n{'='*70}")
        print("SUMMARY")
        print(f"{'='*70}")
        print(f"Files Scanned:         {self.files_scanned}")
        print(f"Files Modified:        {self.files_modified}")
        print(f"Total Replacements:    {self.total_replacements}")
        
        if self.dry_run:
            print(f"\n⚠️  DRY RUN MODE - No files were actually modified")
        elif self.create_backup:
            print(f"\n💾 Backup files created with .bak extension")
        
        print(f"{'='*70}\n")
    
    def run(self) -> None:
        """Execute the find and replace operation."""
        try:
            self.walk_directory()
            self.print_summary()
        except KeyboardInterrupt:
            print("\n\n⚠️  Operation cancelled by user")
            sys.exit(1)
        except Exception as e:
            print(f"\n❌ Error: {e}")
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Recursively find and replace text in files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Replace 'old_name' with 'new_name' in all Python files
  python find_and_replace.py "old_name" "new_name" /path/to/project -e .py
  
  # Case-insensitive replacement in all text files (dry run)
  python find_and_replace.py "TODO" "DONE" . -e .txt -i --dry-run
  
  # Replace in multiple file types without backups
  python find_and_replace.py "foo" "bar" /project -e .js .jsx .ts .tsx --no-backup
        """
    )
    
    parser.add_argument(
        'search',
        help='Text to search for'
    )
    
    parser.add_argument(
        'replace',
        help='Text to replace with'
    )
    
    parser.add_argument(
        'directory',
        nargs='?',
        default='.',
        help='Directory to search (default: current directory)'
    )
    
    parser.add_argument(
        '-e', '--extensions',
        nargs='+',
        help='File extensions to process (e.g., .py .txt .js)'
    )
    
    parser.add_argument(
        '-x', '--exclude',
        nargs='+',
        default=[],
        help='Additional directories to exclude'
    )
    
    parser.add_argument(
        '-i', '--ignore-case',
        action='store_true',
        help='Case-insensitive search'
    )
    
    parser.add_argument(
        '--no-backup',
        action='store_true',
        help='Do not create backup files'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be changed without modifying files'
    )
    
    args = parser.parse_args()
    
    # Create and run the tool
    tool = FindAndReplace(
        search_text=args.search,
        replace_text=args.replace,
        directory=args.directory,
        file_extensions=args.extensions,
        exclude_dirs=set(['.git', '__pycache__', 'node_modules', '.venv', 'venv'] + args.exclude),
        case_sensitive=not args.ignore_case,
        create_backup=not args.no_backup,
        dry_run=args.dry_run
    )
    
    tool.run()


if __name__ == '__main__':
    main()
