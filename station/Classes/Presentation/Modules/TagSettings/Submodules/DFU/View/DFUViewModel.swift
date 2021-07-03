import Foundation
import Combine
import RuuviOntology

final class DFUViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    @Published var downloadProgress: Double = 0

    private var bag = Set<AnyCancellable>()
    private let input = PassthroughSubject<Event, Never>()
    private let interactor: DFUInteractorInput
    private let ruuviTag: RuuviTagSensor

    init(
        interactor: DFUInteractorInput,
        ruuviTag: RuuviTagSensor
    ) {
        self.interactor = interactor
        self.ruuviTag = ruuviTag
        Publishers.system(
            initial: state,
            reduce: Self.reduce,
            scheduler: RunLoop.main,
            feedbacks: [
                self.whenLoading(),
                self.whenServing(),
                self.whenReading(),
                self.whenDownloading(),
                self.userInput(input: input.eraseToAnyPublisher())
            ]
        )
        .assign(to: \.state, on: self)
        .store(in: &bag)
    }

    deinit {
        bag.removeAll()
    }

    func send(event: Event) {
        input.send(event)
    }
}

extension DFUViewModel {
    enum State {
        case idle
        case loading
        case loaded(LatestRelease)
        case serving(LatestRelease)
        case ready(LatestRelease, CurrentRelease?)
        case noNeedToUpgrade(LatestRelease, CurrentRelease?)
        case isAbleToUpgrade(LatestRelease, CurrentRelease?)
        case reading(LatestRelease)
        case downloading(LatestRelease)
        case downloaded(LatestRelease, URL)
        case error(Error)
    }

    enum Event {
        case onAppear
        case onLoaded(LatestRelease)
        case onDidFailLoading(Error)
        case onServed(CurrentRelease?)
        case onLoadedAndServed(LatestRelease, CurrentRelease?)
        case onStartUpgrade(LatestRelease)
        case onRead(LatestRelease, URL)
        case onDidFailReading(LatestRelease, Error)
        case onDownloading(LatestRelease, Double)
        case onListeningToBootDevice(LatestRelease, URL)
        case onDidFailDownloading(Error)
    }
}

extension DFUViewModel {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func reduce(_ state: State, _ event: Event) -> State {
        switch state {
        case .idle:
            switch event {
            case .onAppear:
                return .loading
            default:
                return state
            }
        case .loading:
            switch event {
            case let .onDidFailLoading(error):
                return .error(error)
            case let .onLoaded(latestRelease):
                return .loaded(latestRelease)
            default:
                return state
            }
        case let .loaded(latestRelease):
            return .serving(latestRelease)
        case let .serving(latestRelease):
            switch event {
            case let .onServed(currentRelease):
                return .ready(latestRelease, currentRelease)
            default:
                return state
            }
        case let .ready(latestRelease, currentRelease):
            if isRecommendedToUpdate(
                latestRelease: latestRelease,
                currentRelease: currentRelease
            ) {
                return .isAbleToUpgrade(latestRelease, currentRelease)
            } else {
                return .noNeedToUpgrade(latestRelease, currentRelease)
            }
        case .noNeedToUpgrade:
            return state
        case .isAbleToUpgrade:
            switch event {
            case .onStartUpgrade(let latestRelease):
                return .reading(latestRelease)
            default:
                return state
            }
        case .reading:
            switch event {
            case let .onRead(latestRelease, fileUrl):
                return .downloaded(latestRelease, fileUrl)
            case let .onDidFailReading(latestRelease, _):
                return .downloading(latestRelease)
            default:
                return state
            }
        case .downloading:
            switch event {
            case let .onListeningToBootDevice(latestRelease, fileUrl):
                return .downloaded(latestRelease, fileUrl)
            default:
                return state
            }
        case .downloaded:
            return state
        case .error:
            return state
        }
    }

    static func isRecommendedToUpdate(
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?
    ) -> Bool {
        guard let currentRelease = currentRelease else { return true }
        return !currentRelease.version.contains(latestRelease.version)
    }

    func whenReading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .reading(latestRelease) = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.read(release: latestRelease)
                .map { fileUrl in
                    return Event.onRead(latestRelease, fileUrl)
                }
                .catch { error in Just(Event.onDidFailReading(latestRelease, error)) }
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }
    }

    func whenServing() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .serving = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.serveCurrentRelease(for: sSelf.ruuviTag)
                .map(Event.onServed)
                .catch { _ in Just(Event.onServed(nil)) }
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }
    }

    func whenLoading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .loading = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.loadLatestRelease()
                .map(Event.onLoaded)
                .catch { Just(Event.onDidFailLoading($0)) }
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }
    }

    func whenDownloading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .downloading(latestRelease) = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.download(release: latestRelease)
                .compactMap({ [weak sSelf] response in
                    switch response {
                    case .response(let fileUrl):
                        return Event.onListeningToBootDevice(latestRelease, fileUrl)
                    case .progress(let percentage):
                        sSelf?.downloadProgress = percentage
                        return nil
                    }
                })
                .catch { Just(Event.onDidFailDownloading($0)) }
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }
    }

    func userInput(input: AnyPublisher<Event, Never>) -> Feedback<State, Event> {
        Feedback(run: { _ in
            return input
        })
    }
}
