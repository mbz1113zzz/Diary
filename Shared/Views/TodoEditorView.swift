import SwiftUI
import SwiftData

struct TodoEditorView: View {
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [TodoItem]
    @State private var newTodoTitle = ""

    init(date: Date) {
        self.date = date
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _todos = Query(
            filter: #Predicate<TodoItem> { todo in
                todo.date >= start && todo.date < end
            },
            sort: [SortDescriptor(\.createdAt)]
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(todos) { todo in
                HStack(spacing: 8) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                        .onTapGesture {
                            todo.isCompleted.toggle()
                        }
                    Text(todo.title)
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    Spacer()
                    Button(role: .destructive) {
                        modelContext.delete(todo)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("添加待办...", text: $newTodoTitle)
                    .onSubmit { addTodo() }
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                Button(action: addTodo) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(newTodoTitle.isEmpty)
                .buttonStyle(.plain)
            }
        }
    }

    private func addTodo() {
        guard !newTodoTitle.isEmpty else { return }
        let todo = TodoItem(
            title: newTodoTitle,
            date: DateFormatters.startOfDay(date)
        )
        modelContext.insert(todo)
        newTodoTitle = ""
    }
}
