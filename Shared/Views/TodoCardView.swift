import SwiftUI

struct TodoCardView: View {
    let todos: [TodoItem]
    var onToggle: ((TodoItem) -> Void)? = nil

    private var completed: Int { todos.filter(\.isCompleted).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("今日待办", systemImage: "checkmark.circle")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(todos.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(todos) { todo in
                HStack(spacing: 8) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                        .onTapGesture { onToggle?(todo) }
                    Text(todo.title)
                        .font(.body)
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
