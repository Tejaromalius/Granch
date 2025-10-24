package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/list"
	"github.com/google/uuid"
)

// Map of display names to actual branch prefixes
var categories = []struct {
	Display string
	Code    string
}{
	{"CI/CD", "ci"},
	{"Feature", "feat"},
	{"Fix", "fix"},
	{"Performance", "perf"},
	{"Refactor", "refactor"},
	{"Test", "test"},
}

// branchItem represents a branch in the list
type branchItem struct {
	name string
}

func (b branchItem) Title() string       { return b.name }
func (b branchItem) Description() string { return "" }
func (b branchItem) FilterValue() string { return b.name }

// categoryItem represents a category in the list
type categoryItem struct {
	Display string
	Code    string
}

func (c categoryItem) Title() string       { return c.Display }
func (c categoryItem) Description() string { return "" }
func (c categoryItem) FilterValue() string { return c.Display }

// model represents the TUI state
type model struct {
	stage          int // 0 = select branch, 1 = select category
	branches       list.Model
	categories     list.Model
	selectedBranch branchItem
	err            error
	width          int
	height         int
}

func newModel() model {
	branchDelegate := list.NewDefaultDelegate()
	branchDelegate.ShowDescription = false
	branchDelegate.SetSpacing(0)

	categoryDelegate := list.NewDefaultDelegate()
	categoryDelegate.ShowDescription = false
	categoryDelegate.SetSpacing(0)

	branchList := list.New([]list.Item{}, branchDelegate, 0, 0)
	branchList.SetShowTitle(false)
	branchList.SetShowStatusBar(false)
	branchList.SetShowHelp(false)
	branchList.SetShowPagination(false)
	branchList.SetFilteringEnabled(false)

	categoryList := list.New([]list.Item{}, categoryDelegate, 0, 0)
	categoryList.SetShowTitle(false)
	categoryList.SetShowStatusBar(false)
	categoryList.SetShowHelp(false)
	categoryList.SetShowPagination(false)
	categoryList.SetFilteringEnabled(false)

	return model{
		stage:      0,
		branches:   branchList,
		categories: categoryList,
		width:      80,
		height:     20,
	}
}

// Message structs
type branchesMsgWithSelection struct {
	items      []list.Item
	selectedIx int
}
type errMsg struct{ err error }

// Init: start fetching branches
func (m model) Init() tea.Cmd {
	return tea.Batch(fetchBranchesCmd(), tea.EnterAltScreen)
}

// Fetch branches and determine current branch
func fetchBranchesCmd() tea.Cmd {
	return func() tea.Msg {
		currCmd := exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD")
		currOut, currErr := currCmd.Output()
		currentBranch := ""
		if currErr == nil {
			currentBranch = string(bytes.TrimSpace(currOut))
		}

		cmd := exec.Command("git", "for-each-ref",
			"--sort=-committerdate", "refs/heads/",
			"--format=%(refname:short)")
		out, err := cmd.Output()
		if err != nil {
			return errMsg{err}
		}

		lines := bytes.Split(bytes.TrimSpace(out), []byte("\n"))
		var items []list.Item
		selectedIndex := 0
		for i, line := range lines {
			branch := string(line)
			if branch != "" {
				items = append(items, branchItem{name: branch})
				if branch == currentBranch {
					selectedIndex = i
				}
			}
		}
		return branchesMsgWithSelection{items, selectedIndex}
	}
}

// Create and switch to new branch
func createAndCheckoutBranch(branchName string) error {
	cmd := exec.Command("git", "checkout", "-b", branchName)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// Update handles messages and user input
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case branchesMsgWithSelection:
		m.branches.SetItems(msg.items)
		if len(msg.items) > 0 {
			m.branches.Select(msg.selectedIx)
		}
		return m, nil

	case errMsg:
		m.err = msg.err
		return m, nil

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.branches.SetSize(msg.Width, msg.Height-5)
		m.categories.SetSize(msg.Width, msg.Height-5)
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q", "esc":
			return m, tea.Quit

		case "enter":
			if m.stage == 0 {
				if len(m.branches.Items()) == 0 {
					m.err = fmt.Errorf("no branches found")
					return m, nil
				}

				selected, ok := m.branches.SelectedItem().(branchItem)
				if !ok {
					m.err = fmt.Errorf("failed to get selected branch")
					return m, nil
				}
				m.selectedBranch = selected

				var catItems []list.Item
				for _, c := range categories {
					catItems = append(catItems, categoryItem{Display: c.Display, Code: c.Code})
				}
				m.categories.SetItems(catItems)
				m.categories.Select(0)
				m.stage = 1
				m.err = nil
				return m, nil

			} else if m.stage == 1 {
				selectedCat, ok := m.categories.SelectedItem().(categoryItem)
				if !ok {
					m.err = fmt.Errorf("failed to get selected category")
					return m, nil
				}

				id := uuid.New()
				branchName := fmt.Sprintf("@%s/%s", selectedCat.Code, id.String()[:8])

				// Create branch
				err := createAndCheckoutBranch(branchName)
				if err != nil {
					m.err = fmt.Errorf("failed to create branch: %v", err)
					return m, nil
				}

				fmt.Printf("\n✅ Created and switched to branch: %s\n", branchName)
				return m, tea.Quit
			}
		}
	}

	if m.stage == 0 {
		var cmd tea.Cmd
		m.branches, cmd = m.branches.Update(msg)
		return m, cmd
	}
	var cmd tea.Cmd
	m.categories, cmd = m.categories.Update(msg)
	return m, cmd
}

// View renders each stage
func (m model) View() string {
	if m.err != nil {
		return fmt.Sprintf("\n❌ Error: %v\n\nPress q or Ctrl+C to quit.\n", m.err)
	}

	if m.stage == 0 {
		header := "\n📜 Select a branch:\n\n"
		footer := "\n↑/↓: navigate • enter: select • q: quit\n"
		return header + m.branches.View() + footer
	}
	header := "\n🔧 Select a category:\n\n"
	footer := "\n↑/↓: navigate • enter: confirm • q: quit\n"
	return header + m.categories.View() + footer
}

func main() {
	p := tea.NewProgram(newModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Println("Error running program:", err)
		os.Exit(1)
	}
}

