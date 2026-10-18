using System;
using System.Collections.ObjectModel;
using System.Windows.Input;
using System.Windows.Threading;
using Talkies.Windows.Models;
using Talkies.Windows.Services;

namespace Talkies.Windows.ViewModels
{
    /// <summary>Paged, searchable view of the local transcript history.</summary>
    public sealed class HistoryViewModel : ViewModelBase, IDisposable
    {
        public const int PageSize = 50;

        private readonly ITranscriptHistoryStore _store;
        private readonly Func<string, string, bool> _confirm;
        private readonly Func<string, bool> _copy;
        private readonly Dispatcher _dispatcher;
        private string _searchText = string.Empty;
        private int _pageIndex;
        private int _totalCount;
        private string _status = string.Empty;

        public HistoryViewModel(
            ITranscriptHistoryStore store,
            Func<string, string, bool>? confirm = null,
            Func<string, bool>? copy = null)
        {
            _store = store;
            _confirm = confirm ?? DialogHelper.ShowConfirmation;
            _copy = copy ?? (text => TextInjector.TrySetClipboardText(text));
            _dispatcher = Dispatcher.CurrentDispatcher;

            CopyCommand = new RelayCommand(p => Copy(p as TranscriptRecord), p => p is TranscriptRecord);
            DeleteCommand = new RelayCommand(p => Delete(p as TranscriptRecord), p => p is TranscriptRecord);
            ClearAllCommand = new RelayCommand(_ => ClearAll(), _ => _totalCount > 0 || HasSearch);
            NextPageCommand = new RelayCommand(_ => { _pageIndex++; Reload(); }, _ => HasNextPage);
            PreviousPageCommand = new RelayCommand(_ => { _pageIndex--; Reload(); }, _ => HasPreviousPage);

            _store.Changed += OnStoreChanged;
            Reload();
        }

        public ObservableCollection<TranscriptRecord> Items { get; } = new();

        public ICommand CopyCommand { get; }
        public ICommand DeleteCommand { get; }
        public ICommand ClearAllCommand { get; }
        public ICommand NextPageCommand { get; }
        public ICommand PreviousPageCommand { get; }

        public string SearchText
        {
            get => _searchText;
            set
            {
                if (!SetProperty(ref _searchText, value ?? string.Empty)) return;
                _pageIndex = 0;
                Reload();
            }
        }

        public string Status { get => _status; private set => SetProperty(ref _status, value); }

        public int PageCount => Math.Max(1, (int)Math.Ceiling(_totalCount / (double)PageSize));
        public string PageLabel => $"Page {_pageIndex + 1} of {PageCount}";
        public bool HasNextPage => _pageIndex + 1 < PageCount;
        public bool HasPreviousPage => _pageIndex > 0;
        public bool IsEmpty => Items.Count == 0;
        private bool HasSearch => !string.IsNullOrWhiteSpace(_searchText);

        public void Reload()
        {
            try
            {
                _totalCount = _store.Count(_searchText);
                _pageIndex = Math.Clamp(_pageIndex, 0, PageCount - 1);
                var page = _store.GetPage(_searchText, _pageIndex * PageSize, PageSize);
                Items.Clear();
                foreach (var record in page) Items.Add(record);
                Status = _totalCount switch
                {
                    0 when HasSearch => "No saved transcripts match your search.",
                    0 => "No saved transcripts yet. Finished dictations appear here while “Save transcript history” is on.",
                    1 => "1 transcript",
                    _ => $"{_totalCount} transcripts",
                };
            }
            catch (Exception ex)
            {
                // Exception messages from SQLite describe the failure, never the stored text.
                Logger.Error($"Loading transcript history failed: {ex.GetType().Name}: {ex.Message}");
                Items.Clear();
                Status = $"Transcript history could not be loaded ({ex.Message}).";
            }

            OnPropertyChanged(nameof(PageCount));
            OnPropertyChanged(nameof(PageLabel));
            OnPropertyChanged(nameof(HasNextPage));
            OnPropertyChanged(nameof(HasPreviousPage));
            OnPropertyChanged(nameof(IsEmpty));
            CommandManager.InvalidateRequerySuggested();
        }

        private void Copy(TranscriptRecord? record)
        {
            if (record is null) return;
            Status = _copy(record.Text) ? "Copied to the clipboard." : "The clipboard is busy. Try again.";
        }

        private void Delete(TranscriptRecord? record)
        {
            if (record is null) return;
            try
            {
                _store.Delete(record.Id);
            }
            catch (Exception ex)
            {
                Logger.Error($"Deleting a transcript failed: {ex.GetType().Name}: {ex.Message}");
                Status = $"The transcript could not be deleted ({ex.Message}).";
            }
        }

        private void ClearAll()
        {
            if (!_confirm("Clear transcript history", "Delete every saved transcript from this PC? This cannot be undone."))
                return;
            try
            {
                _store.Clear();
            }
            catch (Exception ex)
            {
                Logger.Error($"Clearing transcript history failed: {ex.GetType().Name}: {ex.Message}");
                Status = $"Transcript history could not be cleared ({ex.Message}).";
            }
        }

        private void OnStoreChanged(object? sender, EventArgs e)
        {
            if (_dispatcher.CheckAccess()) Reload();
            else _dispatcher.BeginInvoke(Reload);
        }

        public void Dispose() => _store.Changed -= OnStoreChanged;
    }
}
