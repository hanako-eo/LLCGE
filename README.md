# LLCGE

**LLCGE** (*Low-Level Code Generator Engine*) is a framework for low-level code generation that takes intermediate representation (IR) and transforms it into machine code optimized for one or more target hardware architectures. Inspired by projects like **LLVM** and **MLIR**, LLCGE focuses on flexibility, performance, and adaptability, while offering hardware-specific optimization possibilities.

## Objectives

LLCGE aims to provide a series of specialized tools for low-level code compilation and generation. The project is based on three main principles:

1. **Modular development**: Each component of the project, written in **Zig**, is designed to be agnostic, meaning independent and reusable across different contexts. However, some components may have dependencies between them, which will be clearly documented in their respective sub-projects.

2. **Extensibility**: LLCGE is designed to allow developers to easily create and integrate their own extensions or modules. This ensures that new features or architecture targets can be added without needing to modify the core of the project.

3. **Maintainability**: LLCGE emphasizes long-term maintainability. The code is written with clarity and simplicity in mind and is documented and tested as thoroughly as possible. This allows the community to contribute easily without risking the stability of the project. Additionally, the modular design reduces the risk of regressions by isolating critical components.

## Components

LLCGE is organized into several sub-projects and libraries, each with a specific goal within the code generation ecosystem:

### 1. [diagnostic](./diagnostic/README.md)
An error management and detailed reporting system that facilitates error detection and provides comprehensive, enriched logs. This module helps manage complex errors during the different stages of the compilation and code generation process.

### 2. [llcge](./llcge/README.md)
This is the core component that containing LLCGE’s IR, optimization passes, and generation of machine code (or object files, or assembly files).

## License

This projet is under [MIT license](./LICENSE). Each LLCGE project has it's own license, please, refert to the specific project to know the license.
