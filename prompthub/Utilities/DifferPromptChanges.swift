//
//  DifferPromptChanges.swift
//  prompthub
//
//  Created by leetao on 2025/8/6.
//

import DifferenceKit

func createDiffWithDifferenceKit(old oldLines: [String], new newLines: [String]) -> [DiffResult] {
    let stagedChangeset = StagedChangeset(source: oldLines, target: newLines)

    // --- 步骤 1: 累加所有阶段的变更 ---
    // 我们必须遍历 StagedChangeset 中的每一个 Changeset，
    // 并将它们的变更信息累加起来。

    var deletedOldIndices = Set<Int>()
    var insertedNewIndices = Set<Int>()

    for changeset in stagedChangeset {
        // a) 累加简单的删除
        changeset.elementDeleted.forEach { deletedOldIndices.insert($0.element) }

        // b) 累加简单的插入
        changeset.elementInserted.forEach { insertedNewIndices.insert($0.element) }
        
        // c) 累加移动操作 (视为一次删除和一次插入)
        for move in changeset.elementMoved {
            deletedOldIndices.insert(move.source.element)
            insertedNewIndices.insert(move.target.element)
        }

        // d) 累加更新操作 (也视为一次删除和一次插入)
        for update in changeset.elementUpdated {
            // 注意: `elementUpdated` 的路径指向的是新数组的索引。
            // 我们的双指针算法会自动将旧行视为删除，所以只需标记新行为插入。
            insertedNewIndices.insert(update.element)
        }
    }
    
    // --- 步骤 2: 生成结果 (此部分逻辑不变，因为它依赖于已完全累加的索引集) ---
    var results: [DiffResult] = []
    var oldIndex = 0
    var newIndex = 0

    while oldIndex < oldLines.count || newIndex < newLines.count {
        let isOldInBounds = oldIndex < oldLines.count
        let isNewInBounds = newIndex < newLines.count
        
        let isOldLineRemoved = isOldInBounds && deletedOldIndices.contains(oldIndex)
        let isNewLineInserted = isNewInBounds && insertedNewIndices.contains(newIndex)

        // 我们需要一个更简单的逻辑来处理所有情况
        if isOldLineRemoved {
            results.append(.removed(oldLines[oldIndex]))
            oldIndex += 1
        } else if isNewLineInserted {
            results.append(.added(newLines[newIndex]))
            newIndex += 1
        } else {
            // 如果两个索引都没有被标记为删除或插入，那么它就是共同行。
            if isOldInBounds {
                results.append(.common(oldLines[oldIndex]))
                oldIndex += 1
                newIndex += 1
            } else {
                // oldLines 已经处理完，但 newLines 还有，这应该在 isNewLineInserted 中被捕获。
                // 如果两个都处理完了，就退出。
                break
            }
        }
    }
    
    return results
}
