import Foundation
import Testing
@testable import CineConnect

@MainActor
@Suite
struct MovieDetailViewModelTests {
    @Test func loadingSucceedsAndPublishesDetail() async {
        let repository = FakeMovieRepository()
        let expected = MovieDetail(title: "T", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil)
        repository.detailResult = .success(expected)
        let viewModel = MovieDetailViewModel(getMovieDetail: GetMovieDetailUseCase(repository: repository))

        await viewModel.loadMovieDetail(slug: "/in/movies/x/1")

        #expect(viewModel.movieDetail?.title == "T")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.detailError == nil)
    }

    @Test func failurePublishesNetworkErrorAndClearsLoading() async {
        let repository = FakeMovieRepository()
        repository.detailResult = .failure(FakeMovieRepository.FakeError.unconfigured)
        let viewModel = MovieDetailViewModel(getMovieDetail: GetMovieDetailUseCase(repository: repository))

        await viewModel.loadMovieDetail(slug: "/in/movies/x/1")

        #expect(viewModel.movieDetail == nil)
        #expect(viewModel.detailError == .networkError)
        #expect(viewModel.isLoading == false)
    }

    @Test func cancellationLeavesNoErrorState() async {
        let repository = FakeMovieRepository()
        repository.detailResult = .failure(CancellationError())
        let viewModel = MovieDetailViewModel(getMovieDetail: GetMovieDetailUseCase(repository: repository))

        await viewModel.loadMovieDetail(slug: "/in/movies/x/1")

        // A cancelled load must not surface as a user-facing error - see
        // MovieDetailViewModel.loadMovieDetail's `catch is CancellationError`.
        #expect(viewModel.detailError == nil)
    }
}
