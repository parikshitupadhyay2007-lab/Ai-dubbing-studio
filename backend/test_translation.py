import argostranslate.package
import argostranslate.translate
import gc
import os
import resource


def memory_usage():
    usage = resource.getrusage(
        resource.RUSAGE_SELF
    ).ru_maxrss

    return round(usage / 1024, 2)


def install_model(source, target):
    print(
        f'Finding {source} -> {target} model...',
        flush=True
    )

    available = (
        argostranslate.package
        .get_available_packages()
    )

    matching = [
        p for p in available
        if p.from_code == source
        and p.to_code == target
    ]

    if not matching:
        raise RuntimeError(
            f'No free model available: {source} -> {target}'
        )

    package = matching[0]

    path = package.download()

    argostranslate.package.install_from_path(path)

    print(
        f'Installed {source} -> {target}',
        flush=True
    )


print('Starting free translation test', flush=True)

print(
    'Initial memory (MB):',
    memory_usage(),
    flush=True
)

install_model('ja', 'en')
install_model('en', 'hi')

gc.collect()

print(
    'Memory after installation (MB):',
    memory_usage(),
    flush=True
)

japanese = 'こんにちは。今日はいい天気ですね。'

english = argostranslate.translate.translate(
    japanese,
    'ja',
    'en'
)

print('English:', english, flush=True)

hindi = argostranslate.translate.translate(
    english,
    'en',
    'hi'
)

print('Hindi:', hindi, flush=True)

print(
    'Peak memory (MB):',
    memory_usage(),
    flush=True
)

print('TEST COMPLETE', flush=True)
