using System;
using System.IO;
using System.Linq;
using Talkies.Windows.Models;
using Talkies.Windows.Services;
using Talkies.Windows.ViewModels;
using Xunit;

namespace Talkies.Windows.Tests.ViewModels;

public sealed class HistoryViewModelTests : IDisposable
{
    private static readonly DateTimeOffset BaseTime = new(2026, 10, 1, 12, 0, 0, TimeSpan.Zero);
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "talkies-history-vm-" + Guid.NewGuid().ToString("N"));
    private readonly TranscriptHistoryStore _store;

    public HistoryViewModelTests()
    {
        _store = new TranscriptHistoryStore(Path.Combine(_directory, TranscriptHistoryStore.FileName));
    }

    public void Dispose()
    {
        if (Directory.Exists(_directory)) Directory.Delete(_directory, recursive: true);
    }

    [Fact]
    public void Pages_NewestFirst()
    {
        for (var i = 0; i < HistoryViewModel.PageSize + 5; i++)
            _store.Add(new NewTranscript(BaseTime.AddSeconds(i), $"t{i}"));
        using var vm = new HistoryViewModel(_store, (_, _) => false, _ => true);

        Assert.Equal(HistoryViewModel.PageSize, vm.Items.Count);
        Assert.Equal($"t{HistoryViewModel.PageSize + 4}", vm.Items[0].Text);
        Assert.Equal("Page 1 of 2", vm.PageLabel);
        Assert.True(vm.HasNextPage);

        vm.NextPageCommand.Execute(null);

        Assert.Equal(5, vm.Items.Count);
        Assert.Equal("t0", vm.Items.Last().Text);
        Assert.False(vm.HasNextPage);
        Assert.True(vm.HasPreviousPage);
    }

    [Fact]
    public void Search_FiltersAndResetsToFirstPage()
    {
        _store.Add(new NewTranscript(BaseTime, "buy milk"));
        _store.Add(new NewTranscript(BaseTime.AddMinutes(1), "call Alice"));
        using var vm = new HistoryViewModel(_store, (_, _) => false, _ => true);

        vm.SearchText = "alice";

        Assert.Equal("call Alice", Assert.Single(vm.Items).Text);
        Assert.Equal("Page 1 of 1", vm.PageLabel);
    }

    [Fact]
    public void CopyAndDelete_ActOnOneTranscript()
    {
        _store.Add(new NewTranscript(BaseTime, "keep"));
        _store.Add(new NewTranscript(BaseTime.AddMinutes(1), "remove"));
        string? copied = null;
        using var vm = new HistoryViewModel(_store, (_, _) => false, text => { copied = text; return true; });

        vm.CopyCommand.Execute(vm.Items[0]);
        vm.DeleteCommand.Execute(vm.Items[0]);

        Assert.Equal("remove", copied);
        Assert.Equal("keep", Assert.Single(vm.Items).Text);
    }

    [Fact]
    public void ClearAll_RequiresConfirmation()
    {
        _store.Add(new NewTranscript(BaseTime, "something"));
        var confirm = false;
        var prompts = 0;
        using var vm = new HistoryViewModel(_store, (_, _) => { prompts++; return confirm; }, _ => true);

        vm.ClearAllCommand.Execute(null);
        Assert.Equal(1, _store.Count());

        confirm = true;
        vm.ClearAllCommand.Execute(null);

        Assert.Equal(2, prompts);
        Assert.Equal(0, _store.Count());
        Assert.Empty(vm.Items);
        Assert.True(vm.IsEmpty);
    }
}
